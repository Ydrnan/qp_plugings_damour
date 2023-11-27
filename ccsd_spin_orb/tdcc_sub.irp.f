subroutine run_tdcc()

  implicit none

  double precision, allocatable  :: t1(:,:), t2(:,:,:,:), tau(:,:,:,:), tau_t(:,:,:,:)
  double precision, allocatable  :: r1(:,:), r2(:,:,:,:), M1(:,:), M2(:,:,:,:)
  double precision, allocatable  :: f_oo(:,:), f_ov(:,:), f_vv(:,:), f_o(:), f_v(:)
  double precision, allocatable  :: v_oooo(:,:,:,:), v_vooo(:,:,:,:), v_ovoo(:,:,:,:)
  double precision, allocatable  :: v_oovo(:,:,:,:), v_ooov(:,:,:,:), v_vvoo(:,:,:,:)
  double precision, allocatable  :: v_vovo(:,:,:,:), v_voov(:,:,:,:), v_ovvo(:,:,:,:)
  double precision, allocatable  :: v_ovov(:,:,:,:), v_oovv(:,:,:,:)
  double precision, allocatable  :: cF_oo(:,:), cF_ov(:,:), cF_vv(:,:)
  double precision, allocatable  :: cW_oooo(:,:,:,:), cW_ovvo(:,:,:,:)
  double precision, allocatable :: all_err(:,:), all_t(:,:)
  integer(bit_kind), allocatable :: det(:,:)
  integer, allocatable           :: list_occ(:,:), list_vir(:,:)
  integer                        :: nO,nV,nO_m,nV_m,nO_S(2),nV_S(2),n_spin(4)
  integer                        :: ma,mb,na,nb
  logical                        :: not_converged
  integer                        :: nb_iter,i,j,a,b
  double precision               :: uncorr_energy,energy,W_ba,max_r,max_r1,max_r2
  double precision               :: ta,tb,ti,tf,tbi,tfi
  
  allocate(det(N_int,2))
  
  nO = cc_nOab
  nV = cc_nVab
  det = psi_det(:,:,cc_ref)
  print*,'Reference determinant:'
  call print_det(det,N_int)

  ! Extract active orb
  call extract_open_spin_orb(nO,nV,det,ma,mb,na,nb)
  print*,ma,mb,na,nb

  ! Number of occ/vir spin orb per spin
  nO_S = cc_nO_S !(/nOa,nOb/)
  nV_S = cc_nV_S !(/nVa,nVb/)

  ! Maximal number of occ/vir 
  nO_m = cc_nO_m !max(nOa, nOb)
  nV_m = cc_nV_m !max(nVa, nVb)

  allocate(list_occ(nO_m,2), list_vir(nV_m,2))
  list_occ = cc_list_occ_spin
  list_vir = cc_list_vir_spin
 
  allocate(t1(nO,nV),t2(nO,nO,nV,nV), tau(nO,nO,nV,nV), tau_t(nO,nO,nV,nV))
  allocate(r1(nO,nV),r2(nO,nO,nV,nV))
  allocate(M1(nO,nV),M2(nO,nO,nV,nV))
  allocate(v_oooo(nO,nO,nO,nO))
  allocate(v_ovoo(nO,nV,nO,nO))
  allocate(v_oovo(nO,nO,nV,nO))
  allocate(v_ooov(nO,nO,nO,nV))
  allocate(v_vvoo(nV,nV,nO,nO))
  allocate(v_ovvo(nO,nV,nV,nO))
  allocate(v_ovov(nO,nV,nO,nV))
  allocate(v_oovv(nO,nO,nV,nV))
  allocate(f_o(nO), f_v(nV))
  allocate(f_oo(nO, nO))
  allocate(f_ov(nO, nV))
  allocate(f_vv(nV, nV))
  allocate(cF_oo(nO,nO), cF_ov(nO,nV), cF_vv(nV,nV))
  allocate(cW_oooo(nO,nO,nO,nO), cW_ovvo(nO,nV,nV,nO))

  ! Allocation for the diis
  if (cc_update_method == 'diis') then
    allocate(all_err(nO*nV+nO*nO*nV*nV,cc_diis_depth), all_t(nO*nV+nO*nO*nV*nV,cc_diis_depth))
    all_err = 0d0
    all_t   = 0d0
  endif

  call gen_f_spin(det, nO_m,nO_m, nO_S,nO_S, list_occ,list_occ, nO,nO, f_oo)
  call gen_f_spin(det, nO_m,nV_m, nO_S,nV_S, list_occ,list_vir, nO,nV, f_ov)
  call gen_f_spin(det, nV_m,nV_m, nV_S,nV_S, list_vir,list_vir, nV,nV, f_vv)

  ! Diag elements
  do i = 1, nO
    f_o(i) = f_oo(i,i)
  enddo
  do i = 1, nV
    f_v(i) = f_vv(i,i)
  enddo

  ! Bi electronic integrals from list
  ! OOOO
  call gen_v_spin(nO_m,nO_m,nO_m,nO_m, nO_S,nO_S,nO_S,nO_S, list_occ,list_occ,list_occ,list_occ, nO,nO,nO,nO, v_oooo)

  ! OOO V
  call gen_v_spin(nO_m,nV_m,nO_m,nO_m, nO_S,nV_S,nO_S,nO_S, list_occ,list_vir,list_occ,list_occ, nO,nV,nO,nO, v_ovoo)
  call gen_v_spin(nO_m,nO_m,nV_m,nO_m, nO_S,nO_S,nV_S,nO_S, list_occ,list_occ,list_vir,list_occ, nO,nO,nV,nO, v_oovo)
  call gen_v_spin(nO_m,nO_m,nO_m,nV_m, nO_S,nO_S,nO_S,nV_S, list_occ,list_occ,list_occ,list_vir, nO,nO,nO,nV, v_ooov)

  ! OO VV
  call gen_v_spin(nV_m,nV_m,nO_m,nO_m, nV_S,nV_S,nO_S,nO_S, list_vir,list_vir,list_occ,list_occ, nV,nV,nO,nO, v_vvoo)
  call gen_v_spin(nO_m,nV_m,nV_m,nO_m, nO_S,nV_S,nV_S,nO_S, list_occ,list_vir,list_vir,list_occ, nO,nV,nV,nO, v_ovvo)
  call gen_v_spin(nO_m,nV_m,nO_m,nV_m, nO_S,nV_S,nO_S,nV_S, list_occ,list_vir,list_occ,list_vir, nO,nV,nO,nV, v_ovov)
  call gen_v_spin(nO_m,nO_m,nV_m,nV_m, nO_S,nO_S,nV_S,nV_S, list_occ,list_occ,list_vir,list_vir, nO,nO,nV,nV, v_oovv)
  
  call guess_t1(nO,nV,f_o,f_v,f_ov,t1)
  call guess_t2(nO,nV,f_o,f_v,v_oovv,t2)

  ! Set the active-active t2 to 0
  t2(ma,nb,na,mb) = 0d0
  t2(ma,nb,mb,na) = 0d0
  t2(nb,ma,na,mb) = 0d0
  t2(nb,ma,mb,na) = 0d0
  call compute_tau_spin(nO,nV,t1,t2,tau)
  call compute_tau_t_spin(nO,nV,t1,t2,tau_t)

  ! Loop init
  nb_iter = 0
  not_converged = .True.
  r1 = 0d0
  r2 = 0d0
  max_r1 = 0d0
  max_r2 = 0d0

  call det_energy(det,uncorr_energy)
  print*,'Det energy', uncorr_energy
  call ccsd_energy_spin(nO,nV,t1,t2,F_ov,v_oovv,energy)
  print*,'guess energy', uncorr_energy+energy, energy

  write(*,'(A77)') ' -----------------------------------------------------------------------------'
  write(*,'(A77)') ' |   It.  |       E(CCSD) (Ha) | Correlation (Ha) |  Conv. T1  |  Conv. T2  |'
  write(*,'(A77)') ' -----------------------------------------------------------------------------'

  call wall_time(ta)

  ! Loop
  do while (not_converged)

    !print*,'t2',t2
    ! Intermediates
    call wall_time(tbi)
    call compute_cF_oo(nO,nV,t1,tau_t,F_oo,F_ov,v_ooov,v_oovv,cF_oo)
    call compute_cF_ov(nO,nV,t1,F_ov,v_oovv,cF_ov)
    call compute_cF_vv(nO,nV,t1,tau_t,F_ov,F_vv,v_oovv,cF_vv)

    call compute_cW_oooo(nO,nV,t1,t2,tau,v_oooo,v_ooov,v_oovv,cW_oooo)
    call compute_cW_ovvo(nO,nV,t1,t2,tau,v_ovvo,v_oovo,v_oovv,cW_ovvo)

    ! Residuals
    call compute_r1_spin(nO,nV,t1,t2,f_o,f_v,F_ov,cF_oo,cF_ov,cF_vv,v_oovo,v_ovov,r1)
    call compute_r2_spin(nO,nV,t1,t2,tau,f_o,f_v,cF_oo,cF_ov,cF_vv,cW_oooo,cW_ovvo,v_ovoo,v_oovv,v_ovvo,r2)

    !print*,'r2',r2
    W_ba = -r2(ma,nb,na,mb)
    !print*,'W_ba',W_ba
  
    ! Init 
    M1 = 0d0
    M2 = 0d0
    !!call compute_M1_A(nO,nV,det,t1,t2,M1)
    call ost1ia_opt(nO,nV,det,t1,t2,M1,M2)
    call ost1ai_opt(nO,nV,det,t1,t2,M1,M2)
    call ost1ii_opt(nO,nV,det,t1,t2,M1,M2)
    !!call compute_M2_A(nO,nV,det,t1,t2,M2)
    call ost2aaia_opt(nO,nV,det,t1,t2,M2)
    call ost2aaii_opt(nO,nV,det,t1,t2,M2)
    call ost2aiaa_opt(nO,nV,det,t1,t2,M2)
    call ost2iiaa_opt(nO,nV,det,t1,t2,M2)
    call ost2aiai1_opt(nO,nV,det,t1,t2,M2)
    call ost2aiai2_opt(nO,nV,det,t1,t2,M2)
    call ost2iiai1_opt(nO,nV,det,t1,t2,M2)
    call ost2iiai2_opt(nO,nV,det,t1,t2,M2)
    call ost2aiii1_opt(nO,nV,det,t1,t2,M2)
    call ost2aiii2_opt(nO,nV,det,t1,t2,M2)
    call ost2iiii1_opt(nO,nV,det,t1,t2,M2)
    call ost2iiii2_opt(nO,nV,det,t1,t2,M2)
    call ost2iiii3_opt(nO,nV,det,t1,t2,M2)
    call ost2iiii4_opt(nO,nV,det,t1,t2,M2)

    !print*,'M1',M1
    !M1 = 0d0
    !M2 = 0d0

    r1 = r1 + M1 * W_ba
    r2 = r2 + M2 * W_ba
    !print*,'M1',M1
    !print*,'M2',M2

    !print*,r2(ma,nb,na,mb)
    !print*,r2(ma,nb,mb,na)
    !print*,r2(nb,ma,na,mb)
    !print*,r2(nb,ma,mb,na)
    r2(ma,nb,na,mb) = 0d0
    r2(ma,nb,mb,na) = 0d0
    r2(nb,ma,na,mb) = 0d0
    r2(nb,ma,mb,na) = 0d0
    
    ! Max elements in the residuals
    max_r1 = maxval(abs(r1))
    max_r2 = maxval(abs(r2))
    max_r  = max(max_r1,max_r2)

    ! Update
    if (cc_update_method == 'diis') then
      call update_t_ccsd_diis_v3(nO,nV,nb_iter,f_o,f_v,r1,r2,t1,t2,all_err,all_t)

    ! Standard update as T = T - Delta
    elseif (cc_update_method == 'none') then
      call update_t1(nO,nV,f_o,f_v,r1,t1)
      call update_t2(nO,nV,f_o,f_v,r2,t2)
    else
      print*,'Unkonw cc_method_method: '//cc_update_method
    endif

    ! Enforced to be zero
    t2(ma,nb,na,mb) = 0d0
    t2(ma,nb,mb,na) = 0d0
    t2(nb,ma,na,mb) = 0d0
    t2(nb,ma,mb,na) = 0d0
    
    call compute_tau_spin(nO,nV,t1,t2,tau)
    call compute_tau_t_spin(nO,nV,t1,t2,tau_t)

    ! Print
    call ccsd_energy_spin(nO,nV,t1,t2,F_ov,v_oovv,energy)
    print*,energy,W_ba
    print*,'Energy of the singlet S:',uncorr_energy+energy+W_ba
    print*,'Energy of the triplet T:',uncorr_energy+energy-W_ba
    call wall_time(tfi)
    write(*,'(A3,I6,A3,F18.12,A3,F16.12,A3,1pE10.2,A3,1pE10.2,A2)') ' | ',nb_iter,' | ', &
         uncorr_energy+energy,' | ', energy,' | ', max_r1,' | ', max_r2,' |'

    ! Convergence
    nb_iter = nb_iter + 1
    if (max_r < cc_thresh_conv .or. nb_iter > cc_max_iter) then
      not_converged = .False.
    endif
  enddo
  
  write(*,'(A77)') ' -----------------------------------------------------------------------------'
  call wall_time(tb)
  print*,'Time: ',tb-ta, ' s'
  print*,''
  if (max_r < cc_thresh_conv) then
    write(*,'(A30,I6,A11)') ' Successful convergence after ', nb_iter, ' iterations'
  else
    write(*,'(A26,I6,A11)') ' Failed convergence after ', nb_iter, ' iterations'
  endif
  print*,''
  write(*,'(A15,F18.12,A3)') ' E(CCSD)  = ', uncorr_energy+energy, ' Ha'
  write(*,'(A15,F18.12,A3)') ' E(S)     = ', uncorr_energy+energy+W_ba, ' Ha'
  write(*,'(A15,F18.12,A3)') ' E(T)     = ', uncorr_energy+energy-W_ba, ' Ha'
  write(*,'(A15,F18.12,A3)') ' Correlation = ', energy, ' Ha'
  write(*,'(A19,F18.12,A3)') ' Correlation (S) = ', energy+W_ba, ' Ha'
  write(*,'(A19,F18.12,A3)') ' Correlation (T) = ', energy-W_ba, ' Ha'
  write(*,'(A15,1pE10.2,A3)')' Conv        = ', max_r

  print*,'Reference determinant:'
  call print_det(det,N_int)
  
  call write_t1(nO,nV,t1)
  call write_t2(nO,nV,t2)
  
  ! Deallocate
  if (cc_update_method == 'diis') then
     deallocate(all_err,all_t)
  endif
  deallocate(tau,tau_t)
  deallocate(r1,r2)
  deallocate(cF_oo,cF_ov,cF_vv)
  deallocate(cW_oooo,cW_ovvo)
  deallocate(v_oooo)
  deallocate(v_ovoo,v_oovo)
  deallocate(v_ovvo,v_ovov,v_oovv)
  deallocate(t1,t2)

end

! M1

!subroutine compute_M1_A(nO,nV,det,t1_A,t2_A,M1_A)
!
!  implicit none
!
!  integer, intent(in)           :: nO,nV
!  integer(bit_kind), intent(in) :: det(N_int,2)
!  double precision, intent(in)  :: t1_A(nO,nV), t2_A(nO,nO,nV,nV)
!  
!  double precision, intent(out) :: M1_A(nO,nV)
!
!  integer                       :: ia,ib,na,nb,ma,mb,aa,ab
!  integer                       :: i_ia, i_aa
!  integer                       :: i_ib, i_ab
!  integer                       :: f_ia, f_aa
!  integer                       :: f_ib, f_ab
!
!  ! List of open spin orbitals
!  call extract_open_spin_orb(nO,nV,det,ma,mb,na,nb)
!
!  i_ia = 1
!  i_ib = cc_nOa + 1
!  i_aa = 1
!  i_ab = cc_nVa + 1
!
!  f_ia = cc_nOa
!  f_ib = cc_nOab
!  f_aa = cc_nVa
!  f_ab = cc_nVab
!
!  !print*,'ia',i_ia,f_ia
!  !print*,'ib',i_ib,f_ib
!  !print*,'aa',i_aa,f_aa
!  !print*,'ab',i_ab,f_ab
!  
!  ! Init
!  M1_A = 0d0
!
!  ! ### Spin case: i_a, a_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M1_A(ia,aa) = M1_A(ia,aa) & 
!      -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!      -1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, na, ab)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M1_A(ia,na) = M1_A(ia,na) & 
!    -1.0d0 * t2_A(ma, ib, na, mb)
!  enddo
!
!  !! Deltas:((ma, ia))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M1_A(ma,aa) = M1_A(ma,aa) & 
!    +1.0d0 * t2_A(ma, nb, na, ab)
!  enddo
!
!  ! ### Spin case: i_b, a_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M1_A(ib,ab) = M1_A(ib,ab) & 
!      -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!      -1.0d0 * t1_A(ia, na) * t2_A(ma, nb, aa, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M1_A(ib,mb) = M1_A(ib,mb) & 
!    -1.0d0 * t2_A(ia, nb, na, mb)
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M1_A(nb,ab) = M1_A(nb,ab) & 
!    +1.0d0 * t2_A(ma, nb, aa, mb)
!  enddo
!  
!end
!
!! M1 act
!
!subroutine compute_M1_A_act(nO,nV,det,t1_A,t2_A,M1_A)
!
!  implicit none
!
!  integer, intent(in)           :: nO,nV
!  integer(bit_kind), intent(in) :: det(N_int,2)
!  double precision, intent(in)  :: t1_A(nO,nV), t2_A(nO,nO,nV,nV)
!  
!  double precision, intent(out) :: M1_A(nO,nV)
!
!  integer                       :: ia,ib,na,nb,ma,mb,aa,ab
!  integer                       :: i_ia, i_aa
!  integer                       :: i_ib, i_ab
!  integer                       :: f_ia, f_aa
!  integer                       :: f_ib, f_ab
!
!  ! List of open spin orbitals
!  call extract_open_spin_orb(nO,nV,det,ma,mb,na,nb)
!
!  i_ia = 1
!  i_ib = cc_nOa + 1
!  i_aa = 1
!  i_ab = cc_nVa + 1
!
!  f_ia = cc_nOa
!  f_ib = cc_nOab
!  f_aa = cc_nVa
!  f_ab = cc_nVab
!
!  !print*,'ia',i_ia,f_ia
!  !print*,'ib',i_ib,f_ib
!  !print*,'aa',i_aa,f_aa
!  !print*,'ab',i_ab,f_ab
!  
!  ! Init
!  M1_A = 0d0
!
!  ! ### Spin case: i_a, a_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M1_A(ia,aa) = M1_A(ia,aa) & 
!      -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!      -1.0d0 * t1_A(ma, na) * t2_A(nb, ib, ab, mb) & 
!      -1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!      +1.0d0 * t1_A(nb, mb) * t2_A(ma, ib, na, ab) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ma, na) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M1_A(ia,na) = M1_A(ia,na) & 
!    -1.0d0 * t2_A(ma, ib, na, mb) & 
!    -1.0d0 * t1_A(ma, na) * t1_A(ib, mb)
!  enddo
!
!  !! Deltas:((ma, ia))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M1_A(ma,aa) = M1_A(ma,aa) & 
!    +1.0d0 * t2_A(ma, nb, na, ab) & 
!    +1.0d0 * t1_A(nb, ab) * t1_A(ma, na)
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia))
!  M1_A(ma,na) = M1_A(ma,na) & 
!  +1.0d0 * t1_A(ma, na)
!
!  ! ### Spin case: i_b, a_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M1_A(ib,ab) = M1_A(ib,ab) & 
!      -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!      -1.0d0 * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!      +1.0d0 * t1_A(ma, na) * t2_A(ia, nb, aa, mb) & 
!      -1.0d0 * t1_A(nb, mb) * t2_A(ma, ia, aa, na) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M1_A(ib,mb) = M1_A(ib,mb) & 
!    -1.0d0 * t2_A(ia, nb, na, mb) & 
!    -1.0d0 * t1_A(ia, na) * t1_A(nb, mb)
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M1_A(nb,ab) = M1_A(nb,ab) & 
!    +1.0d0 * t2_A(ma, nb, aa, mb) & 
!    +1.0d0 * t1_A(ma, aa) * t1_A(nb, mb)
!  enddo
!
!  !! Deltas:((mb, ab), (nb, ib))
!  M1_A(nb,mb) = M1_A(nb,mb) & 
!  +1.0d0 * t1_A(nb, mb)
!  
!end
!
!! M2
!
!subroutine compute_M2_A(nO,nV,det,t1_A,t2_A,M2_A)
!
!  implicit none
!
!  integer, intent(in)           :: nO,nV
!  integer(bit_kind), intent(in) :: det(N_int,2)
!  double precision, intent(in)  :: t1_A(nO,nV), t2_A(nO,nO,nV,nV)
!  
!  double precision, intent(out) :: M2_A(nO,nO,nV,nV)
!
!  integer                       :: ia,ib,ja,jb,na,nb,ma,mb,aa,ab,ba,bb
!  integer                       :: i_ia, i_ja, i_aa, i_ba
!  integer                       :: i_ib, i_jb, i_ab, i_bb
!  integer                       :: f_ia, f_ja, f_aa, f_ba
!  integer                       :: f_ib, f_jb, f_ab, f_bb
!
!  ! List of open spin orbitals
!  call extract_open_spin_orb(nO,nV,det,ma,mb,na,nb)
!
!  i_ia = 1
!  i_ja = 1
!  i_ib = cc_nOa + 1
!  i_jb = cc_nOa + 1
!  i_aa = 1
!  i_ba = 1
!  i_ab = cc_nVa + 1
!  i_bb = cc_nVa + 1
!
!  f_ia = cc_nOa
!  f_ja = cc_nOa
!  f_ib = cc_nOab
!  f_jb = cc_nOab
!  f_aa = cc_nVa
!  f_ba = cc_nVa
!  f_ab = cc_nVab
!  f_bb = cc_nVab
!  
!  ! Init
!  M2_A = 0d0
!
!    ! ### Spin case: i_a, j_a, a_a, b_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ia,ja,aa,ba) = M2_A(ia,ja,aa,ba) & 
!          -1.0d0 * t2_A(nb, jb, ab, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t2_A(nb, ib, ab, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, jb, na, ab) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t2_A(ma, ib, na, ab) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ib, jb, bb, mb) & 
!          -1.0d0 * t2_A(ib, jb, ab, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t2_A(nb, jb, ab, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t2_A(nb, ib, ab, mb) * t2_A(ma, jb, na, bb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(jb, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ib, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(jb, mb) * t2_A(ma, ib, na, ab) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(ib, mb) * t2_A(ma, jb, na, ab) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ib, mb) * t2_A(ma, nb, na, ab)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,ja,na,ba) = M2_A(ia,ja,na,ba) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, ib, na, bb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, jb, na, bb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ia,ja,aa,na) = M2_A(ia,ja,aa,na) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, ib, na, ab) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, jb, na, ab) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,ma,aa,ba) = M2_A(ia,ma,aa,ba) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ib, na, ab) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ma,ja,aa,ba) = M2_A(ma,ja,aa,ba) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, jb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, jb, na, ab) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ia,ma,na,ba) = M2_A(ia,ma,na,ba) & 
!      -1.0d0 * t2_A(ma, ib, na, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ia,ma,aa,na) = M2_A(ia,ma,aa,na) & 
!      +1.0d0 * t2_A(ma, ib, na, ab)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,ja,na,ba) = M2_A(ma,ja,na,ba) & 
!      +1.0d0 * t2_A(ma, jb, na, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ma,ja,aa,na) = M2_A(ma,ja,aa,na) & 
!      -1.0d0 * t2_A(ma, jb, na, ab)
!    enddo
!  enddo
!
!  ! ### Spin case: i_a, j_b, a_a, b_b ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ia,jb,aa,bb) = M2_A(ia,jb,aa,bb) & 
!          -1.0d0 * t2_A(ja, nb, ba, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t2_A(ma, ib, ba, ab) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t2_A(ma, nb, ba, ab) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t2_A(ja, ib, na, ab) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t2_A(ja, nb, na, ab) * t2_A(ma, ib, ba, mb) & 
!          +1.0d0 * t2_A(ma, ib, na, ab) * t2_A(ja, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ja, ib, ba, mb) & 
!          +1.0d0 * t2_A(nb, ib, ab, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t2_A(ja, ib, na, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ja, na) * t2_A(ma, ib, ba, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ib, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t2_A(nb, ib, ab, mb) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ib, mb) * t2_A(ja, nb, na, ab) & 
!          +1.0d0 * t1_A(ja, na) * t1_A(ib, mb) * t2_A(ma, nb, ba, ab) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ja, na) * t1_A(ib, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ib, mb) * t2_A(ma, nb, na, ab)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ia,jb,na,bb) = M2_A(ia,jb,na,bb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ja, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ma, ib, ba, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, ja, ba, na) & 
!        +1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ia,jb,aa,mb) = M2_A(ia,jb,aa,mb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ja, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(nb, ib, ab, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ja, nb, na, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ja, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ja, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ia,nb,aa,bb) = M2_A(ia,nb,aa,bb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, ba, mb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(nb, ib, ab, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, ba, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, ba, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ma,jb,aa,bb) = M2_A(ma,jb,aa,bb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ja, ba, na) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ja, nb, na, ab) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ma, nb, ba, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ja, na) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      M2_A(ia,jb,na,mb) = M2_A(ia,jb,na,mb) & 
!      +1.0d0 * t2_A(ja, ib, na, mb) & 
!      +1.0d0 * t1_A(ja, na) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ia,nb,na,bb) = M2_A(ia,nb,na,bb) & 
!      -1.0d0 * t2_A(ma, ib, ba, mb) & 
!      -1.0d0 * t1_A(ma, ba) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ia,nb,aa,mb) = M2_A(ia,nb,aa,mb) & 
!      -1.0d0 * t2_A(nb, ib, ab, mb) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ma,jb,na,bb) = M2_A(ma,jb,na,bb) & 
!      -1.0d0 * t2_A(ma, ja, ba, na) & 
!      -1.0d0 * t1_A(ma, ba) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ma,jb,aa,mb) = M2_A(ma,jb,aa,mb) & 
!      -1.0d0 * t2_A(ja, nb, na, ab) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia), (nb, jb))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ma,nb,aa,bb) = M2_A(ma,nb,aa,bb) & 
!      +1.0d0 * t2_A(ma, nb, ba, ab) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M2_A(ia,nb,na,mb) = M2_A(ia,nb,na,mb) & 
!    -1.0d0 * t1_A(ib, mb)
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    M2_A(ma,jb,na,mb) = M2_A(ma,jb,na,mb) & 
!    -1.0d0 * t1_A(ja, na)
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia), (nb, jb))
!  do bb = i_bb, f_bb
!    if (bb == mb) cycle 
!    ba = bb - cc_nVa
!    M2_A(ma,nb,na,bb) = M2_A(ma,nb,na,bb) & 
!    +1.0d0 * t1_A(ma, ba)
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ia), (nb, jb))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M2_A(ma,nb,aa,mb) = M2_A(ma,nb,aa,mb) & 
!    +1.0d0 * t1_A(nb, ab)
!  enddo
!
!  ! ### Spin case: i_a, j_b, a_b, b_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ia,jb,ab,ba) = M2_A(ia,jb,ab,ba) & 
!          +1.0d0 * t2_A(ja, nb, aa, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t2_A(ma, ib, aa, bb) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t2_A(ma, nb, aa, bb) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t2_A(ma, ja, aa, na) * t2_A(nb, ib, bb, mb) & 
!          +1.0d0 * t2_A(ja, ib, aa, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t2_A(ja, nb, aa, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t2_A(ma, ib, aa, mb) * t2_A(ja, nb, na, bb) & 
!          +1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ja, ib, na, bb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ib, mb) * t2_A(ja, nb, na, bb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ja, na) * t2_A(ma, ib, aa, mb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ib, mb) * t2_A(ma, ja, aa, na) & 
!          -1.0d0 * t1_A(ja, na) * t1_A(ib, mb) * t2_A(ma, nb, aa, bb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ja, na) * t1_A(ib, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t2_A(ma, nb, aa, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,jb,mb,ba) = M2_A(ia,jb,mb,ba) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ja, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(nb, ib, bb, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ja, nb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t1_A(ja, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ja, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ia,jb,ab,na) = M2_A(ia,jb,ab,na) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ja, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ma, ib, aa, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, ja, aa, na) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,nb,ab,ba) = M2_A(ia,nb,ab,ba) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(nb, ib, bb, mb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ib, aa, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, aa, bb) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ma,jb,ab,ba) = M2_A(ma,jb,ab,ba) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ja, nb, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ja, aa, na) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ma, nb, aa, bb) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ja, na) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, na, bb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      M2_A(ia,jb,mb,na) = M2_A(ia,jb,mb,na) & 
!      -1.0d0 * t2_A(ja, ib, na, mb) & 
!      -1.0d0 * t1_A(ja, na) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ia,nb,mb,ba) = M2_A(ia,nb,mb,ba) & 
!      +1.0d0 * t2_A(nb, ib, bb, mb) & 
!      +1.0d0 * t1_A(nb, bb) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ia,nb,ab,na) = M2_A(ia,nb,ab,na) & 
!      +1.0d0 * t2_A(ma, ib, aa, mb) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,jb,mb,ba) = M2_A(ma,jb,mb,ba) & 
!      +1.0d0 * t2_A(ja, nb, na, bb) & 
!      +1.0d0 * t1_A(nb, bb) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ma,jb,ab,na) = M2_A(ma,jb,ab,na) & 
!      +1.0d0 * t2_A(ma, ja, aa, na) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia), (nb, jb))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,nb,ab,ba) = M2_A(ma,nb,ab,ba) & 
!      -1.0d0 * t2_A(ma, nb, aa, bb) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M2_A(ia,nb,mb,na) = M2_A(ia,nb,mb,na) & 
!    +1.0d0 * t1_A(ib, mb)
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    M2_A(ma,jb,mb,na) = M2_A(ma,jb,mb,na) & 
!    +1.0d0 * t1_A(ja, na)
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ia), (nb, jb))
!  do ba = i_ba, f_ba
!    if (ba == na) cycle 
!    bb = ba + cc_nVa
!    M2_A(ma,nb,mb,ba) = M2_A(ma,nb,mb,ba) & 
!    -1.0d0 * t1_A(nb, bb)
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia), (nb, jb))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M2_A(ma,nb,ab,na) = M2_A(ma,nb,ab,na) & 
!    -1.0d0 * t1_A(ma, aa)
!  enddo
!
!  ! ### Spin case: i_b, j_a, a_a, b_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ib,ja,aa,bb) = M2_A(ib,ja,aa,bb) & 
!          +1.0d0 * t2_A(ma, jb, ba, ab) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t2_A(ia, nb, ba, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t2_A(ma, nb, ba, ab) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t2_A(ia, jb, na, ab) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, jb, na, ab) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t2_A(ia, nb, na, ab) * t2_A(ma, jb, ba, mb) & 
!          +1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ia, jb, ba, mb) & 
!          -1.0d0 * t2_A(nb, jb, ab, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t2_A(ia, jb, na, mb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ia, na) * t2_A(ma, jb, ba, mb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(jb, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t2_A(nb, jb, ab, mb) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(jb, mb) * t2_A(ia, nb, na, ab) & 
!          -1.0d0 * t1_A(ia, na) * t1_A(jb, mb) * t2_A(ma, nb, ba, ab) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ia, na) * t1_A(jb, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(jb, mb) * t2_A(ma, nb, na, ab)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,ja,na,bb) = M2_A(ib,ja,na,bb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ia, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ma, jb, ba, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, ia, ba, na) & 
!        -1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, jb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ib,ja,aa,mb) = M2_A(ib,ja,aa,mb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ia, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(nb, jb, ab, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ia, nb, na, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ia, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,ma,aa,bb) = M2_A(ib,ma,aa,bb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, ia, ba, na) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ia, nb, na, ab) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ma, nb, ba, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ia, na) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(nb,ja,aa,bb) = M2_A(nb,ja,aa,bb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, jb, ba, mb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(nb, jb, ab, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, nb, ba, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, ba, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      M2_A(ib,ja,na,mb) = M2_A(ib,ja,na,mb) & 
!      -1.0d0 * t2_A(ia, jb, na, mb) & 
!      -1.0d0 * t1_A(ia, na) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ib,ma,na,bb) = M2_A(ib,ma,na,bb) & 
!      +1.0d0 * t2_A(ma, ia, ba, na) & 
!      +1.0d0 * t1_A(ma, ba) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ib,ma,aa,mb) = M2_A(ib,ma,aa,mb) & 
!      +1.0d0 * t2_A(ia, nb, na, ab) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,ja,na,bb) = M2_A(nb,ja,na,bb) & 
!      +1.0d0 * t2_A(ma, jb, ba, mb) & 
!      +1.0d0 * t1_A(ma, ba) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(nb,ja,aa,mb) = M2_A(nb,ja,aa,mb) & 
!      +1.0d0 * t2_A(nb, jb, ab, mb) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja), (nb, ib))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,ma,aa,bb) = M2_A(nb,ma,aa,bb) & 
!      -1.0d0 * t2_A(ma, nb, ba, ab) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M2_A(ib,ma,na,mb) = M2_A(ib,ma,na,mb) & 
!    +1.0d0 * t1_A(ia, na)
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    M2_A(nb,ja,na,mb) = M2_A(nb,ja,na,mb) & 
!    +1.0d0 * t1_A(jb, mb)
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja), (nb, ib))
!  do bb = i_bb, f_bb
!    if (bb == mb) cycle 
!    ba = bb - cc_nVa
!    M2_A(nb,ma,na,bb) = M2_A(nb,ma,na,bb) & 
!    -1.0d0 * t1_A(ma, ba)
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ja), (nb, ib))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M2_A(nb,ma,aa,mb) = M2_A(nb,ma,aa,mb) & 
!    -1.0d0 * t1_A(nb, ab)
!  enddo
!
!  ! ### Spin case: i_b, j_a, a_b, b_a ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ib,ja,ab,ba) = M2_A(ib,ja,ab,ba) & 
!          -1.0d0 * t2_A(ma, jb, aa, bb) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t2_A(ia, nb, aa, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, nb, aa, bb) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, ia, aa, na) * t2_A(nb, jb, bb, mb) & 
!          -1.0d0 * t2_A(ia, jb, aa, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t2_A(ma, jb, aa, mb) * t2_A(ia, nb, na, bb) & 
!          +1.0d0 * t2_A(ia, nb, aa, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ia, jb, na, bb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(jb, mb) * t2_A(ia, nb, na, bb) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(ia, na) * t2_A(ma, jb, aa, mb) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(jb, mb) * t2_A(ma, ia, aa, na) & 
!          +1.0d0 * t1_A(ia, na) * t1_A(jb, mb) * t2_A(ma, nb, aa, bb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ia, na) * t1_A(jb, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t2_A(ma, nb, aa, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ib,ja,mb,ba) = M2_A(ib,ja,mb,ba) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ia, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(nb, jb, bb, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ia, nb, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t1_A(ia, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ib,ja,ab,na) = M2_A(ib,ja,ab,na) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ia, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ma, jb, aa, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, ia, aa, na) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, jb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ib,ma,ab,ba) = M2_A(ib,ma,ab,ba) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, ia, aa, na) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ma, nb, aa, bb) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ia, na) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, na, bb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(nb,ja,ab,ba) = M2_A(nb,ja,ab,ba) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(nb, jb, bb, mb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, jb, aa, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, nb, aa, bb) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      M2_A(ib,ja,mb,na) = M2_A(ib,ja,mb,na) & 
!      +1.0d0 * t2_A(ia, jb, na, mb) & 
!      +1.0d0 * t1_A(ia, na) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ib,ma,mb,ba) = M2_A(ib,ma,mb,ba) & 
!      -1.0d0 * t2_A(ia, nb, na, bb) & 
!      -1.0d0 * t1_A(nb, bb) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ib,ma,ab,na) = M2_A(ib,ma,ab,na) & 
!      -1.0d0 * t2_A(ma, ia, aa, na) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(nb,ja,mb,ba) = M2_A(nb,ja,mb,ba) & 
!      -1.0d0 * t2_A(nb, jb, bb, mb) & 
!      -1.0d0 * t1_A(nb, bb) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(nb,ja,ab,na) = M2_A(nb,ja,ab,na) & 
!      -1.0d0 * t2_A(ma, jb, aa, mb) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja), (nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(nb,ma,ab,ba) = M2_A(nb,ma,ab,ba) & 
!      +1.0d0 * t2_A(ma, nb, aa, bb) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M2_A(ib,ma,mb,na) = M2_A(ib,ma,mb,na) & 
!    -1.0d0 * t1_A(ia, na)
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    M2_A(nb,ja,mb,na) = M2_A(nb,ja,mb,na) & 
!    -1.0d0 * t1_A(jb, mb)
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ja), (nb, ib))
!  do ba = i_ba, f_ba
!    if (ba == na) cycle 
!    bb = ba + cc_nVa
!    M2_A(nb,ma,mb,ba) = M2_A(nb,ma,mb,ba) & 
!    +1.0d0 * t1_A(nb, bb)
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja), (nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M2_A(nb,ma,ab,na) = M2_A(nb,ma,ab,na) & 
!    +1.0d0 * t1_A(ma, aa)
!  enddo
!
!  ! ### Spin case: i_b, j_b, a_b, b_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ib,jb,ab,bb) = M2_A(ib,jb,ab,bb) & 
!          -1.0d0 * t2_A(ma, ja, aa, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t2_A(ma, ia, aa, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t2_A(ia, ja, aa, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t2_A(ma, ja, aa, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, ia, aa, na) * t2_A(ja, nb, ba, mb) & 
!          +1.0d0 * t2_A(ja, nb, aa, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t2_A(ia, nb, aa, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ia, ja, ba, na) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t2_A(ja, nb, ba, mb) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t2_A(ia, nb, aa, mb) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t2_A(ja, nb, aa, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t2_A(ma, nb, aa, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,jb,mb,bb) = M2_A(ib,jb,mb,bb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ia, nb, ba, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ja, nb, ba, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ib,jb,ab,mb) = M2_A(ib,jb,ab,mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ia, nb, aa, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ja, nb, aa, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,nb,ab,bb) = M2_A(ib,nb,ab,bb) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, ba, mb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ia, nb, aa, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(nb,jb,ab,bb) = M2_A(nb,jb,ab,bb) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ja, nb, ba, mb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ja, nb, aa, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ib,nb,mb,bb) = M2_A(ib,nb,mb,bb) & 
!      -1.0d0 * t2_A(ia, nb, ba, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ib,nb,ab,mb) = M2_A(ib,nb,ab,mb) & 
!      +1.0d0 * t2_A(ia, nb, aa, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,jb,mb,bb) = M2_A(nb,jb,mb,bb) & 
!      +1.0d0 * t2_A(ja, nb, ba, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(nb,jb,ab,mb) = M2_A(nb,jb,ab,mb) & 
!      -1.0d0 * t2_A(ja, nb, aa, mb)
!    enddo
!  enddo
!
!end
!
!! M2 sign
!
!subroutine compute_M2_A_sign(nO,nV,det,t1_A,t2_A,M2_A)
!
!  implicit none
!
!  integer, intent(in)           :: nO,nV
!  integer(bit_kind), intent(in) :: det(N_int,2)
!  double precision, intent(in)  :: t1_A(nO,nV), t2_A(nO,nO,nV,nV)
!  
!  double precision, intent(out) :: M2_A(nO,nO,nV,nV)
!
!  integer                       :: ia,ib,ja,jb,na,nb,ma,mb,aa,ab,ba,bb
!  integer                       :: i_ia, i_ja, i_aa, i_ba
!  integer                       :: i_ib, i_jb, i_ab, i_bb
!  integer                       :: f_ia, f_ja, f_aa, f_ba
!  integer                       :: f_ib, f_jb, f_ab, f_bb
!
!  ! List of open spin orbitals
!  call extract_open_spin_orb(nO,nV,det,ma,mb,na,nb)
!
!  i_ia = 1
!  i_ja = 1
!  i_ib = cc_nOa + 1
!  i_jb = cc_nOa + 1
!  i_aa = 1
!  i_ba = 1
!  i_ab = cc_nVa + 1
!  i_bb = cc_nVa + 1
!
!  f_ia = cc_nOa
!  f_ja = cc_nOa
!  f_ib = cc_nOab
!  f_jb = cc_nOab
!  f_aa = cc_nVa
!  f_ba = cc_nVa
!  f_ab = cc_nVab
!  f_bb = cc_nVab
!  
!  ! Init
!  M2_A = 0d0
!
!  ! ### Spin case: i_a, j_a, a_a, b_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ia,ja,aa,ba) = M2_A(ia,ja,aa,ba) & 
!          -1.0d0 * t2_A(nb, jb, ab, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t2_A(nb, ib, ab, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, jb, na, ab) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t2_A(ma, ib, na, ab) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ib, jb, bb, mb) & 
!          -1.0d0 * t2_A(ib, jb, ab, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t2_A(nb, jb, ab, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t2_A(nb, ib, ab, mb) * t2_A(ma, jb, na, bb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(jb, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ib, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(jb, mb) * t2_A(ma, ib, na, ab) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(ib, mb) * t2_A(ma, jb, na, ab) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ib, mb) * t2_A(ma, nb, na, ab)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,ja,na,ba) = M2_A(ia,ja,na,ba) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, ib, na, bb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, jb, na, bb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ia,ja,aa,na) = M2_A(ia,ja,aa,na) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, ib, na, ab) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, jb, na, ab) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,ma,aa,ba) = M2_A(ia,ma,aa,ba) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ib, na, ab) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ma,ja,aa,ba) = M2_A(ma,ja,aa,ba) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, jb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, jb, na, ab) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ia,ma,na,ba) = M2_A(ia,ma,na,ba) & 
!      -1.0d0 * t2_A(ma, ib, na, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ia,ma,aa,na) = M2_A(ia,ma,aa,na) & 
!      +1.0d0 * t2_A(ma, ib, na, ab)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,ja,na,ba) = M2_A(ma,ja,na,ba) & 
!      +1.0d0 * t2_A(ma, jb, na, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ma,ja,aa,na) = M2_A(ma,ja,aa,na) & 
!      -1.0d0 * t2_A(ma, jb, na, ab)
!    enddo
!  enddo
!
!  ! ### Spin case: i_a, j_b, a_a, b_b ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ia,jb,aa,bb) = M2_A(ia,jb,aa,bb) & 
!          -1.0d0 * t2_A(ja, nb, ba, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t2_A(ma, ib, ba, ab) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t2_A(ma, nb, ba, ab) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t2_A(ja, ib, na, ab) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t2_A(ja, nb, na, ab) * t2_A(ma, ib, ba, mb) & 
!          +1.0d0 * t2_A(ma, ib, na, ab) * t2_A(ja, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ja, ib, ba, mb) & 
!          +1.0d0 * t2_A(nb, ib, ab, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t2_A(ja, ib, na, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ja, na) * t2_A(ma, ib, ba, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ib, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t2_A(nb, ib, ab, mb) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ib, mb) * t2_A(ja, nb, na, ab) & 
!          +1.0d0 * t1_A(ja, na) * t1_A(ib, mb) * t2_A(ma, nb, ba, ab) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ja, na) * t1_A(ib, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ib, mb) * t2_A(ma, nb, na, ab)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ia,jb,na,bb) = M2_A(ia,jb,na,bb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ja, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ma, ib, ba, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, ja, ba, na) & 
!        +1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ia,jb,aa,mb) = M2_A(ia,jb,aa,mb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ja, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(nb, ib, ab, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ja, nb, na, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ja, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ja, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ia,nb,aa,bb) = M2_A(ia,nb,aa,bb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, ba, mb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(nb, ib, ab, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, ba, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, ba, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ma,jb,aa,bb) = M2_A(ma,jb,aa,bb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ja, ba, na) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ja, nb, na, ab) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ma, nb, ba, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ja, na) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      M2_A(ia,jb,na,mb) = M2_A(ia,jb,na,mb) & 
!      +1.0d0 * t2_A(ja, ib, na, mb) & 
!      +1.0d0 * t1_A(ja, na) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ia,nb,na,bb) = M2_A(ia,nb,na,bb) & 
!      -1.0d0 * t2_A(ma, ib, ba, mb) & 
!      -1.0d0 * t1_A(ma, ba) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ia,nb,aa,mb) = M2_A(ia,nb,aa,mb) & 
!      -1.0d0 * t2_A(nb, ib, ab, mb) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ma,jb,na,bb) = M2_A(ma,jb,na,bb) & 
!      -1.0d0 * t2_A(ma, ja, ba, na) & 
!      -1.0d0 * t1_A(ma, ba) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ma,jb,aa,mb) = M2_A(ma,jb,aa,mb) & 
!      -1.0d0 * t2_A(ja, nb, na, ab) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia), (nb, jb))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ma,nb,aa,bb) = M2_A(ma,nb,aa,bb) & 
!      +1.0d0 * t2_A(ma, nb, ba, ab) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M2_A(ia,nb,na,mb) = M2_A(ia,nb,na,mb) & 
!    -1.0d0 * t1_A(ib, mb)
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    M2_A(ma,jb,na,mb) = M2_A(ma,jb,na,mb) & 
!    -1.0d0 * t1_A(ja, na)
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia), (nb, jb))
!  do bb = i_bb, f_bb
!    if (bb == mb) cycle 
!    ba = bb - cc_nVa
!    M2_A(ma,nb,na,bb) = M2_A(ma,nb,na,bb) & 
!    +1.0d0 * t1_A(ma, ba)
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ia), (nb, jb))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M2_A(ma,nb,aa,mb) = M2_A(ma,nb,aa,mb) & 
!    +1.0d0 * t1_A(nb, ab)
!  enddo
!
!  ! ### Spin case: i_a, j_b, a_b, b_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ia,jb,ab,ba) = M2_A(ia,jb,ab,ba) & 
!          +1.0d0 * t2_A(ja, nb, aa, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t2_A(ma, ib, aa, bb) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t2_A(ma, nb, aa, bb) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t2_A(ma, ja, aa, na) * t2_A(nb, ib, bb, mb) & 
!          +1.0d0 * t2_A(ja, ib, aa, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t2_A(ja, nb, aa, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t2_A(ma, ib, aa, mb) * t2_A(ja, nb, na, bb) & 
!          +1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ja, ib, na, bb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ib, mb) * t2_A(ja, nb, na, bb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ja, na) * t2_A(ma, ib, aa, mb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ib, mb) * t2_A(ma, ja, aa, na) & 
!          -1.0d0 * t1_A(ja, na) * t1_A(ib, mb) * t2_A(ma, nb, aa, bb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ja, na) * t1_A(ib, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t2_A(ma, nb, aa, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,jb,mb,ba) = M2_A(ia,jb,mb,ba) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ja, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(nb, ib, bb, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ja, nb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t1_A(ja, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ja, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ia,jb,ab,na) = M2_A(ia,jb,ab,na) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ja, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ma, ib, aa, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, ja, aa, na) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, ib, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,nb,ab,ba) = M2_A(ia,nb,ab,ba) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(nb, ib, bb, mb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ib, aa, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, aa, bb) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ma,jb,ab,ba) = M2_A(ma,jb,ab,ba) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ja, nb, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ja, aa, na) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ma, nb, aa, bb) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ja, na) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, na, bb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      M2_A(ia,jb,mb,na) = M2_A(ia,jb,mb,na) & 
!      -1.0d0 * t2_A(ja, ib, na, mb) & 
!      -1.0d0 * t1_A(ja, na) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ia,nb,mb,ba) = M2_A(ia,nb,mb,ba) & 
!      +1.0d0 * t2_A(nb, ib, bb, mb) & 
!      +1.0d0 * t1_A(nb, bb) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ia,nb,ab,na) = M2_A(ia,nb,ab,na) & 
!      +1.0d0 * t2_A(ma, ib, aa, mb) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,jb,mb,ba) = M2_A(ma,jb,mb,ba) & 
!      +1.0d0 * t2_A(ja, nb, na, bb) & 
!      +1.0d0 * t1_A(nb, bb) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ma,jb,ab,na) = M2_A(ma,jb,ab,na) & 
!      +1.0d0 * t2_A(ma, ja, aa, na) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia), (nb, jb))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,nb,ab,ba) = M2_A(ma,nb,ab,ba) & 
!      -1.0d0 * t2_A(ma, nb, aa, bb) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M2_A(ia,nb,mb,na) = M2_A(ia,nb,mb,na) & 
!    +1.0d0 * t1_A(ib, mb)
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    M2_A(ma,jb,mb,na) = M2_A(ma,jb,mb,na) & 
!    +1.0d0 * t1_A(ja, na)
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ia), (nb, jb))
!  do ba = i_ba, f_ba
!    if (ba == na) cycle 
!    bb = ba + cc_nVa
!    M2_A(ma,nb,mb,ba) = M2_A(ma,nb,mb,ba) & 
!    -1.0d0 * t1_A(nb, bb)
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia), (nb, jb))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M2_A(ma,nb,ab,na) = M2_A(ma,nb,ab,na) & 
!    -1.0d0 * t1_A(ma, aa)
!  enddo
!
!  ! ### Spin case: i_b, j_a, a_a, b_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ib,ja,aa,bb) = M2_A(ib,ja,aa,bb) & 
!          +1.0d0 * t2_A(ma, jb, ba, ab) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t2_A(ia, nb, ba, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t2_A(ma, nb, ba, ab) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t2_A(ia, jb, na, ab) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, jb, na, ab) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t2_A(ia, nb, na, ab) * t2_A(ma, jb, ba, mb) & 
!          +1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ia, jb, ba, mb) & 
!          -1.0d0 * t2_A(nb, jb, ab, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t2_A(ia, jb, na, mb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ia, na) * t2_A(ma, jb, ba, mb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(jb, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t2_A(nb, jb, ab, mb) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(jb, mb) * t2_A(ia, nb, na, ab) & 
!          -1.0d0 * t1_A(ia, na) * t1_A(jb, mb) * t2_A(ma, nb, ba, ab) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ia, na) * t1_A(jb, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(jb, mb) * t2_A(ma, nb, na, ab)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,ja,na,bb) = M2_A(ib,ja,na,bb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ia, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ma, jb, ba, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, ia, ba, na) & 
!        -1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, jb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ib,ja,aa,mb) = M2_A(ib,ja,aa,mb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ia, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(nb, jb, ab, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ia, nb, na, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ia, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,ma,aa,bb) = M2_A(ib,ma,aa,bb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, ia, ba, na) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ia, nb, na, ab) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ma, nb, ba, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ia, na) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, na, ab)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(nb,ja,aa,bb) = M2_A(nb,ja,aa,bb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, jb, ba, mb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(nb, jb, ab, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, nb, ba, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, ba, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      M2_A(ib,ja,na,mb) = M2_A(ib,ja,na,mb) & 
!      -1.0d0 * t2_A(ia, jb, na, mb) & 
!      -1.0d0 * t1_A(ia, na) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ib,ma,na,bb) = M2_A(ib,ma,na,bb) & 
!      +1.0d0 * t2_A(ma, ia, ba, na) & 
!      +1.0d0 * t1_A(ma, ba) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ib,ma,aa,mb) = M2_A(ib,ma,aa,mb) & 
!      +1.0d0 * t2_A(ia, nb, na, ab) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,ja,na,bb) = M2_A(nb,ja,na,bb) & 
!      +1.0d0 * t2_A(ma, jb, ba, mb) & 
!      +1.0d0 * t1_A(ma, ba) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(nb,ja,aa,mb) = M2_A(nb,ja,aa,mb) & 
!      +1.0d0 * t2_A(nb, jb, ab, mb) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja), (nb, ib))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,ma,aa,bb) = M2_A(nb,ma,aa,bb) & 
!      -1.0d0 * t2_A(ma, nb, ba, ab) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M2_A(ib,ma,na,mb) = M2_A(ib,ma,na,mb) & 
!    +1.0d0 * t1_A(ia, na)
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    M2_A(nb,ja,na,mb) = M2_A(nb,ja,na,mb) & 
!    +1.0d0 * t1_A(jb, mb)
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja), (nb, ib))
!  do bb = i_bb, f_bb
!    if (bb == mb) cycle 
!    ba = bb - cc_nVa
!    M2_A(nb,ma,na,bb) = M2_A(nb,ma,na,bb) & 
!    -1.0d0 * t1_A(ma, ba)
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ja), (nb, ib))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M2_A(nb,ma,aa,mb) = M2_A(nb,ma,aa,mb) & 
!    -1.0d0 * t1_A(nb, ab)
!  enddo
!
!  ! ### Spin case: i_b, j_a, a_b, b_a ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ib,ja,ab,ba) = M2_A(ib,ja,ab,ba) & 
!          -1.0d0 * t2_A(ma, jb, aa, bb) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t2_A(ia, nb, aa, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, nb, aa, bb) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, ia, aa, na) * t2_A(nb, jb, bb, mb) & 
!          -1.0d0 * t2_A(ia, jb, aa, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t2_A(ma, jb, aa, mb) * t2_A(ia, nb, na, bb) & 
!          +1.0d0 * t2_A(ia, nb, aa, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ia, jb, na, bb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(jb, mb) * t2_A(ia, nb, na, bb) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(ia, na) * t2_A(ma, jb, aa, mb) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(jb, mb) * t2_A(ma, ia, aa, na) & 
!          +1.0d0 * t1_A(ia, na) * t1_A(jb, mb) * t2_A(ma, nb, aa, bb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ia, na) * t1_A(jb, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t2_A(ma, nb, aa, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ib,ja,mb,ba) = M2_A(ib,ja,mb,ba) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ia, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(nb, jb, bb, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ia, nb, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t1_A(ia, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ib,ja,ab,na) = M2_A(ib,ja,ab,na) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ia, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ma, jb, aa, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, ia, aa, na) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, jb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ib,ma,ab,ba) = M2_A(ib,ma,ab,ba) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, ia, aa, na) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ma, nb, aa, bb) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ia, na) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, na, bb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(nb,ja,ab,ba) = M2_A(nb,ja,ab,ba) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(nb, jb, bb, mb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, jb, aa, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, nb, aa, bb) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      M2_A(ib,ja,mb,na) = M2_A(ib,ja,mb,na) & 
!      +1.0d0 * t2_A(ia, jb, na, mb) & 
!      +1.0d0 * t1_A(ia, na) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ib,ma,mb,ba) = M2_A(ib,ma,mb,ba) & 
!      -1.0d0 * t2_A(ia, nb, na, bb) & 
!      -1.0d0 * t1_A(nb, bb) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ib,ma,ab,na) = M2_A(ib,ma,ab,na) & 
!      -1.0d0 * t2_A(ma, ia, aa, na) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(nb,ja,mb,ba) = M2_A(nb,ja,mb,ba) & 
!      -1.0d0 * t2_A(nb, jb, bb, mb) & 
!      -1.0d0 * t1_A(nb, bb) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(nb,ja,ab,na) = M2_A(nb,ja,ab,na) & 
!      -1.0d0 * t2_A(ma, jb, aa, mb) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja), (nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(nb,ma,ab,ba) = M2_A(nb,ma,ab,ba) & 
!      +1.0d0 * t2_A(ma, nb, aa, bb) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M2_A(ib,ma,mb,na) = M2_A(ib,ma,mb,na) & 
!    -1.0d0 * t1_A(ia, na)
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    M2_A(nb,ja,mb,na) = M2_A(nb,ja,mb,na) & 
!    -1.0d0 * t1_A(jb, mb)
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ja), (nb, ib))
!  do ba = i_ba, f_ba
!    if (ba == na) cycle 
!    bb = ba + cc_nVa
!    M2_A(nb,ma,mb,ba) = M2_A(nb,ma,mb,ba) & 
!    +1.0d0 * t1_A(nb, bb)
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja), (nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M2_A(nb,ma,ab,na) = M2_A(nb,ma,ab,na) & 
!    +1.0d0 * t1_A(ma, aa)
!  enddo
!
!  ! ### Spin case: i_b, j_b, a_b, b_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ib,jb,ab,bb) = M2_A(ib,jb,ab,bb) & 
!          -1.0d0 * t2_A(ma, ja, aa, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t2_A(ma, ia, aa, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t2_A(ia, ja, aa, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t2_A(ma, ja, aa, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, ia, aa, na) * t2_A(ja, nb, ba, mb) & 
!          +1.0d0 * t2_A(ja, nb, aa, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t2_A(ia, nb, aa, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ia, ja, ba, na) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t2_A(ja, nb, ba, mb) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t2_A(ia, nb, aa, mb) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t2_A(ja, nb, aa, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t2_A(ma, nb, aa, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,jb,mb,bb) = M2_A(ib,jb,mb,bb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ia, nb, ba, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ja, nb, ba, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ib,jb,ab,mb) = M2_A(ib,jb,ab,mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ia, nb, aa, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ja, nb, aa, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ia, nb, na, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,nb,ab,bb) = M2_A(ib,nb,ab,bb) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, ba, mb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ia, nb, aa, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(nb,jb,ab,bb) = M2_A(nb,jb,ab,bb) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ja, nb, ba, mb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ja, nb, aa, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, aa, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ib,nb,mb,bb) = M2_A(ib,nb,mb,bb) & 
!      -1.0d0 * t2_A(ia, nb, ba, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ib,nb,ab,mb) = M2_A(ib,nb,ab,mb) & 
!      +1.0d0 * t2_A(ia, nb, aa, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,jb,mb,bb) = M2_A(nb,jb,mb,bb) & 
!      +1.0d0 * t2_A(ja, nb, ba, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(nb,jb,ab,mb) = M2_A(nb,jb,ab,mb) & 
!      -1.0d0 * t2_A(ja, nb, aa, mb)
!    enddo
!  enddo
!
!end
!
!! M2 act
!
!subroutine compute_M2_A_act(nO,nV,det,t1_A,t2_A,M2_A)
!
!  implicit none
!
!  integer, intent(in)           :: nO,nV
!  integer(bit_kind), intent(in) :: det(N_int,2)
!  double precision, intent(in)  :: t1_A(nO,nV), t2_A(nO,nO,nV,nV)
!  
!  double precision, intent(out) :: M2_A(nO,nO,nV,nV)
!
!  integer                       :: ia,ib,ja,jb,na,nb,ma,mb,aa,ab,ba,bb
!  integer                       :: i_ia, i_ja, i_aa, i_ba
!  integer                       :: i_ib, i_jb, i_ab, i_bb
!  integer                       :: f_ia, f_ja, f_aa, f_ba
!  integer                       :: f_ib, f_jb, f_ab, f_bb
!
!  ! List of open spin orbitals
!  call extract_open_spin_orb(nO,nV,det,ma,mb,na,nb)
!
!  i_ia = 1
!  i_ja = 1
!  i_ib = cc_nOa + 1
!  i_jb = cc_nOa + 1
!  i_aa = 1
!  i_ba = 1
!  i_ab = cc_nVa + 1
!  i_bb = cc_nVa + 1
!
!  f_ia = cc_nOa
!  f_ja = cc_nOa
!  f_ib = cc_nOab
!  f_jb = cc_nOab
!  f_aa = cc_nVa
!  f_ba = cc_nVa
!  f_ab = cc_nVab
!  f_bb = cc_nVab
!  
!  ! Init
!  M2_A = 0d0
!
!  ! ### Spin case: i_a, j_a, a_a, b_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ia,ja,aa,ba) = M2_A(ia,ja,aa,ba) & 
!          -1.0d0 * t2_A(nb, jb, ab, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t2_A(nb, ib, ab, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, jb, na, ab) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t2_A(ma, ib, na, ab) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ib, jb, bb, mb) & 
!          -1.0d0 * t2_A(ib, jb, ab, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t2_A(nb, jb, ab, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t2_A(nb, ib, ab, mb) * t2_A(ma, jb, na, bb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, na) * t2_A(ib, jb, bb, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(jb, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ib, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ma, na) * t2_A(ib, jb, ab, mb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(jb, mb) * t2_A(ma, ib, na, ab) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(ib, mb) * t2_A(ma, jb, na, ab) & 
!          +1.0d0 * t1_A(ma, na) * t1_A(jb, mb) * t2_A(nb, ib, ab, bb) & 
!          -1.0d0 * t1_A(ma, na) * t1_A(ib, mb) * t2_A(nb, jb, ab, bb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ma, na) * t2_A(nb, jb, bb, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(nb, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(jb, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ma, na) * t2_A(nb, ib, bb, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(nb, mb) * t2_A(ma, ib, na, bb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(ib, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ma, na) * t2_A(nb, jb, ab, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(nb, mb) * t2_A(ma, jb, na, ab) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(jb, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ma, na) * t2_A(nb, ib, ab, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(nb, mb) * t2_A(ma, ib, na, ab) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(ib, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ma, na) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(nb, mb) * t2_A(ma, jb, na, bb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(jb, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ma, na) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(nb, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(ib, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ma, na) * t2_A(nb, jb, ab, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(nb, mb) * t2_A(ma, jb, na, ab) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(jb, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ma, na) * t2_A(nb, ib, ab, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(nb, mb) * t2_A(ma, ib, na, ab) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(ib, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,ja,na,ba) = M2_A(ia,ja,na,ba) & 
!        +1.0d0 * t1_A(ma, na) * t2_A(ib, jb, bb, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, ib, na, bb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, jb, na, bb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t1_A(ma, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t1_A(ma, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t1_A(ma, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t1_A(ma, na) * t1_A(ib, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ia,ja,aa,na) = M2_A(ia,ja,aa,na) & 
!        -1.0d0 * t1_A(ma, na) * t2_A(ib, jb, ab, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, ib, na, ab) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, jb, na, ab) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t1_A(ma, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t1_A(ma, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t1_A(ma, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t1_A(ma, na) * t1_A(ib, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,ma,aa,ba) = M2_A(ia,ma,aa,ba) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ib, na, ab) & 
!        -1.0d0 * t1_A(ma, na) * t2_A(nb, ib, ab, bb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t1_A(ma, na) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t1_A(ma, na) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t1_A(ma, na) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t1_A(ma, na)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ma,ja,aa,ba) = M2_A(ma,ja,aa,ba) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, jb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, jb, na, ab) & 
!        +1.0d0 * t1_A(ma, na) * t2_A(nb, jb, ab, bb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t1_A(ma, na) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t1_A(ma, na) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t1_A(ma, na) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t1_A(ma, na)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ia,ma,na,ba) = M2_A(ia,ma,na,ba) & 
!      -1.0d0 * t2_A(ma, ib, na, bb) & 
!      -1.0d0 * t1_A(ia, ba) * t1_A(ma, na) & 
!      +1.0d0 * t1_A(ib, bb) * t1_A(ma, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ia,ma,aa,na) = M2_A(ia,ma,aa,na) & 
!      +1.0d0 * t2_A(ma, ib, na, ab) & 
!      +1.0d0 * t1_A(ia, aa) * t1_A(ma, na) & 
!      -1.0d0 * t1_A(ib, ab) * t1_A(ma, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,ja,na,ba) = M2_A(ma,ja,na,ba) & 
!      +1.0d0 * t2_A(ma, jb, na, bb) & 
!      +1.0d0 * t1_A(ja, ba) * t1_A(ma, na) & 
!      -1.0d0 * t1_A(jb, bb) * t1_A(ma, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ma,ja,aa,na) = M2_A(ma,ja,aa,na) & 
!      -1.0d0 * t2_A(ma, jb, na, ab) & 
!      -1.0d0 * t1_A(ja, aa) * t1_A(ma, na) & 
!      +1.0d0 * t1_A(jb, ab) * t1_A(ma, na)
!    enddo
!  enddo
!
!  ! ### Spin case: i_a, j_b, a_a, b_b ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ia,jb,aa,bb) = M2_A(ia,jb,aa,bb) & 
!          -1.0d0 * t2_A(ja, nb, ba, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t2_A(ma, ib, ba, ab) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t2_A(ma, nb, ba, ab) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t2_A(ja, ib, na, ab) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t2_A(ja, nb, na, ab) * t2_A(ma, ib, ba, mb) & 
!          +1.0d0 * t2_A(ma, ib, na, ab) * t2_A(ja, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ja, ib, ba, mb) & 
!          +1.0d0 * t2_A(nb, ib, ab, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t2_A(ja, ib, na, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ja, na) * t2_A(ma, ib, ba, mb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ma, na) * t2_A(ja, ib, ba, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ib, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t2_A(nb, ib, ab, mb) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ib, mb) * t2_A(ja, nb, na, ab) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(nb, mb) * t2_A(ja, ib, na, ab) & 
!          +1.0d0 * t1_A(ja, na) * t1_A(ib, mb) * t2_A(ma, nb, ba, ab) & 
!          -1.0d0 * t1_A(ja, na) * t1_A(nb, mb) * t2_A(ma, ib, ba, ab) & 
!          -1.0d0 * t1_A(ma, na) * t1_A(ib, mb) * t2_A(ja, nb, ba, ab) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ja, na) * t1_A(ib, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ma, na) * t2_A(ja, nb, ba, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(nb, mb) * t2_A(ma, ja, ba, na) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t1_A(ja, na) * t1_A(nb, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ma, na) * t2_A(nb, ib, ab, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(nb, mb) * t2_A(ma, ib, na, ab) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(ib, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ma, na) * t2_A(ja, nb, ba, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(nb, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t1_A(ja, na) * t1_A(nb, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ma, na) * t2_A(nb, ib, ab, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ib, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(nb, mb) * t2_A(ma, ib, na, ab) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(ib, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ia,jb,na,bb) = M2_A(ia,jb,na,bb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ja, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ma, ib, ba, mb) & 
!        -1.0d0 * t1_A(ma, na) * t2_A(ja, ib, ba, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, ja, ba, na) & 
!        +1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t1_A(ma, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t1_A(ma, na) * t1_A(ib, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ia,jb,aa,mb) = M2_A(ia,jb,aa,mb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ja, ib, na, mb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(nb, ib, ab, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ja, nb, na, ab) & 
!        -1.0d0 * t1_A(nb, mb) * t2_A(ja, ib, na, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ja, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ia,nb,aa,bb) = M2_A(ia,nb,aa,bb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ib, ba, mb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(nb, ib, ab, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, ba, ab) & 
!        +1.0d0 * t1_A(nb, mb) * t2_A(ma, ib, ba, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ma,jb,aa,bb) = M2_A(ma,jb,aa,bb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ma, ja, ba, na) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ja, nb, na, ab) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ma, nb, ba, ab) & 
!        +1.0d0 * t1_A(ma, na) * t2_A(ja, nb, ba, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ja, na) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(jb, bb) * t1_A(nb, ab) * t1_A(ma, na) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(ja, ba) * t1_A(nb, ab) * t1_A(ma, na)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      M2_A(ia,jb,na,mb) = M2_A(ia,jb,na,mb) & 
!      +1.0d0 * t2_A(ja, ib, na, mb) & 
!      +1.0d0 * t1_A(ja, na) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ia,nb,na,bb) = M2_A(ia,nb,na,bb) & 
!      -1.0d0 * t2_A(ma, ib, ba, mb) & 
!      -1.0d0 * t1_A(ma, ba) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ia,nb,aa,mb) = M2_A(ia,nb,aa,mb) & 
!      -1.0d0 * t2_A(nb, ib, ab, mb) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ib, mb) & 
!      +1.0d0 * t1_A(ia, aa) * t1_A(nb, mb) & 
!      -1.0d0 * t1_A(ib, ab) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ma,jb,na,bb) = M2_A(ma,jb,na,bb) & 
!      -1.0d0 * t2_A(ma, ja, ba, na) & 
!      -1.0d0 * t1_A(ma, ba) * t1_A(ja, na) & 
!      +1.0d0 * t1_A(jb, bb) * t1_A(ma, na) & 
!      -1.0d0 * t1_A(ja, ba) * t1_A(ma, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ma,jb,aa,mb) = M2_A(ma,jb,aa,mb) & 
!      -1.0d0 * t2_A(ja, nb, na, ab) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia), (nb, jb))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ma,nb,aa,bb) = M2_A(ma,nb,aa,bb) & 
!      +1.0d0 * t2_A(ma, nb, ba, ab) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M2_A(ia,nb,na,mb) = M2_A(ia,nb,na,mb) & 
!    -1.0d0 * t1_A(ib, mb)
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    M2_A(ma,jb,na,mb) = M2_A(ma,jb,na,mb) & 
!    -1.0d0 * t1_A(ja, na)
!  enddo
!
!  !! Deltas:((na, aa), (ma, ia), (nb, jb))
!  do bb = i_bb, f_bb
!    if (bb == mb) cycle 
!    ba = bb - cc_nVa
!    M2_A(ma,nb,na,bb) = M2_A(ma,nb,na,bb) & 
!    +1.0d0 * t1_A(ma, ba)
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ia), (nb, jb))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M2_A(ma,nb,aa,mb) = M2_A(ma,nb,aa,mb) & 
!    +1.0d0 * t1_A(nb, ab)
!  enddo
!
!  ! ### Spin case: i_a, j_b, a_b, b_a ###
!
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ia,jb,ab,ba) = M2_A(ia,jb,ab,ba) & 
!          +1.0d0 * t2_A(ja, nb, aa, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t2_A(ma, ib, aa, bb) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t2_A(ma, nb, aa, bb) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t2_A(ma, ja, aa, na) * t2_A(nb, ib, bb, mb) & 
!          +1.0d0 * t2_A(ja, ib, aa, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t2_A(ja, nb, aa, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t2_A(ma, ib, aa, mb) * t2_A(ja, nb, na, bb) & 
!          +1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ja, ib, na, bb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t2_A(ja, ib, na, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ib, mb) * t2_A(ja, nb, na, bb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, mb) * t2_A(ja, ib, na, bb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ja, na) * t2_A(ma, ib, aa, mb) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(ma, na) * t2_A(ja, ib, aa, mb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ib, mb) * t2_A(ma, ja, aa, na) & 
!          -1.0d0 * t1_A(ja, na) * t1_A(ib, mb) * t2_A(ma, nb, aa, bb) & 
!          +1.0d0 * t1_A(ja, na) * t1_A(nb, mb) * t2_A(ma, ib, aa, bb) & 
!          +1.0d0 * t1_A(ma, na) * t1_A(ib, mb) * t2_A(ja, nb, aa, bb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ja, na) * t1_A(ib, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ma, na) * t2_A(nb, ib, bb, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(nb, mb) * t2_A(ma, ib, na, bb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(ib, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ma, na) * t2_A(ja, nb, aa, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(nb, mb) * t2_A(ma, ja, aa, na) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t1_A(ja, na) * t1_A(nb, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t2_A(ma, ib, na, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ma, na) * t2_A(nb, ib, bb, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ib, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(nb, mb) * t2_A(ma, ib, na, bb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(ib, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ma, na) * t2_A(ja, nb, aa, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(nb, mb) * t2_A(ma, ja, aa, na) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t1_A(ja, na) * t1_A(nb, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,jb,mb,ba) = M2_A(ia,jb,mb,ba) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ja, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(nb, ib, bb, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ja, nb, na, bb) & 
!        +1.0d0 * t1_A(nb, mb) * t2_A(ja, ib, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t1_A(ja, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ia,jb,ab,na) = M2_A(ia,jb,ab,na) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ja, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ma, ib, aa, mb) & 
!        +1.0d0 * t1_A(ma, na) * t2_A(ja, ib, aa, mb) & 
!        -1.0d0 * t1_A(ib, mb) * t2_A(ma, ja, aa, na) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t1_A(ib, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, ib, na, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t1_A(ma, na) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, ib, na, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t1_A(ma, na) * t1_A(ib, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ia,nb,ab,ba) = M2_A(ia,nb,ab,ba) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(nb, ib, bb, mb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ib, aa, mb) & 
!        +1.0d0 * t1_A(ib, mb) * t2_A(ma, nb, aa, bb) & 
!        -1.0d0 * t1_A(nb, mb) * t2_A(ma, ib, aa, bb) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ib, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ma,jb,ab,ba) = M2_A(ma,jb,ab,ba) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ja, nb, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ma, ja, aa, na) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ma, nb, aa, bb) & 
!        -1.0d0 * t1_A(ma, na) * t2_A(ja, nb, aa, bb) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ja, na) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(jb, ab) * t1_A(nb, bb) * t1_A(ma, na) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ja, aa) * t1_A(nb, bb) * t1_A(ma, na)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      M2_A(ia,jb,mb,na) = M2_A(ia,jb,mb,na) & 
!      -1.0d0 * t2_A(ja, ib, na, mb) & 
!      -1.0d0 * t1_A(ja, na) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ia,nb,mb,ba) = M2_A(ia,nb,mb,ba) & 
!      +1.0d0 * t2_A(nb, ib, bb, mb) & 
!      +1.0d0 * t1_A(nb, bb) * t1_A(ib, mb) & 
!      -1.0d0 * t1_A(ia, ba) * t1_A(nb, mb) & 
!      +1.0d0 * t1_A(ib, bb) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ia,nb,ab,na) = M2_A(ia,nb,ab,na) & 
!      +1.0d0 * t2_A(ma, ib, aa, mb) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(ib, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,jb,mb,ba) = M2_A(ma,jb,mb,ba) & 
!      +1.0d0 * t2_A(ja, nb, na, bb) & 
!      +1.0d0 * t1_A(nb, bb) * t1_A(ja, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ma,jb,ab,na) = M2_A(ma,jb,ab,na) & 
!      +1.0d0 * t2_A(ma, ja, aa, na) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(ja, na) & 
!      -1.0d0 * t1_A(jb, ab) * t1_A(ma, na) & 
!      +1.0d0 * t1_A(ja, aa) * t1_A(ma, na)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ia), (nb, jb))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ma,nb,ab,ba) = M2_A(ma,nb,ab,ba) & 
!      -1.0d0 * t2_A(ma, nb, aa, bb) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (nb, jb))
!  do ia = i_ia, f_ia
!    if (ia == ma) cycle 
!    ib = ia + cc_nOa
!    M2_A(ia,nb,mb,na) = M2_A(ia,nb,mb,na) & 
!    +1.0d0 * t1_A(ib, mb)
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (ma, ia))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    M2_A(ma,jb,mb,na) = M2_A(ma,jb,mb,na) & 
!    +1.0d0 * t1_A(ja, na)
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ia), (nb, jb))
!  do ba = i_ba, f_ba
!    if (ba == na) cycle 
!    bb = ba + cc_nVa
!    M2_A(ma,nb,mb,ba) = M2_A(ma,nb,mb,ba) & 
!    -1.0d0 * t1_A(nb, bb)
!  enddo
!
!  !! Deltas:((na, ba), (ma, ia), (nb, jb))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M2_A(ma,nb,ab,na) = M2_A(ma,nb,ab,na) & 
!    -1.0d0 * t1_A(ma, aa)
!  enddo
!
!  ! ### Spin case: i_b, j_a, a_a, b_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ib,ja,aa,bb) = M2_A(ib,ja,aa,bb) & 
!          +1.0d0 * t2_A(ma, jb, ba, ab) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t2_A(ia, nb, ba, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t2_A(ma, nb, ba, ab) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t2_A(ia, jb, na, ab) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, jb, na, ab) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t2_A(ia, nb, na, ab) * t2_A(ma, jb, ba, mb) & 
!          +1.0d0 * t2_A(ma, nb, na, ab) * t2_A(ia, jb, ba, mb) & 
!          -1.0d0 * t2_A(nb, jb, ab, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t2_A(ia, jb, na, mb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ia, na) * t2_A(ma, jb, ba, mb) & 
!          +1.0d0 * t1_A(nb, ab) * t1_A(ma, na) * t2_A(ia, jb, ba, mb) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(jb, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t2_A(nb, jb, ab, mb) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(jb, mb) * t2_A(ia, nb, na, ab) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(nb, mb) * t2_A(ia, jb, na, ab) & 
!          -1.0d0 * t1_A(ia, na) * t1_A(jb, mb) * t2_A(ma, nb, ba, ab) & 
!          +1.0d0 * t1_A(ia, na) * t1_A(nb, mb) * t2_A(ma, jb, ba, ab) & 
!          +1.0d0 * t1_A(ma, na) * t1_A(jb, mb) * t2_A(ia, nb, ba, ab) & 
!          -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ia, na) * t1_A(jb, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ma, na) * t2_A(ia, nb, ba, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(nb, mb) * t2_A(ma, ia, ba, na) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t1_A(ia, na) * t1_A(nb, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ma, na) * t2_A(nb, jb, ab, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(nb, mb) * t2_A(ma, jb, na, ab) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(jb, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ma, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(nb, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t1_A(ia, na) * t1_A(nb, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ma, na) * t2_A(nb, jb, ab, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(jb, mb) * t2_A(ma, nb, na, ab) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(nb, mb) * t2_A(ma, jb, na, ab) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t1_A(ma, na) * t1_A(jb, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,ja,na,bb) = M2_A(ib,ja,na,bb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ia, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ma, jb, ba, mb) & 
!        +1.0d0 * t1_A(ma, na) * t2_A(ia, jb, ba, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, ia, ba, na) & 
!        -1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t1_A(ma, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t1_A(ma, na) * t1_A(jb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do aa = i_aa, f_aa
!        if (aa == na) cycle 
!        ab = aa + cc_nVa
!        M2_A(ib,ja,aa,mb) = M2_A(ib,ja,aa,mb) & 
!        -1.0d0 * t1_A(nb, ab) * t2_A(ia, jb, na, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(nb, jb, ab, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ia, nb, na, ab) & 
!        +1.0d0 * t1_A(nb, mb) * t2_A(ia, jb, na, ab) & 
!        -1.0d0 * t1_A(nb, ab) * t1_A(ia, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,ma,aa,bb) = M2_A(ib,ma,aa,bb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, ia, ba, na) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ia, nb, na, ab) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ma, nb, ba, ab) & 
!        -1.0d0 * t1_A(ma, na) * t2_A(ia, nb, ba, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(ia, na) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, na, ab) & 
!        -1.0d0 * t1_A(ib, bb) * t1_A(nb, ab) * t1_A(ma, na) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, na, ab) & 
!        +1.0d0 * t1_A(ia, ba) * t1_A(nb, ab) * t1_A(ma, na)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(nb,ja,aa,bb) = M2_A(nb,ja,aa,bb) & 
!        +1.0d0 * t1_A(nb, ab) * t2_A(ma, jb, ba, mb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(nb, jb, ab, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, nb, ba, ab) & 
!        -1.0d0 * t1_A(nb, mb) * t2_A(ma, jb, ba, ab) & 
!        +1.0d0 * t1_A(nb, ab) * t1_A(ma, ba) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      M2_A(ib,ja,na,mb) = M2_A(ib,ja,na,mb) & 
!      -1.0d0 * t2_A(ia, jb, na, mb) & 
!      -1.0d0 * t1_A(ia, na) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ib,ma,na,bb) = M2_A(ib,ma,na,bb) & 
!      +1.0d0 * t2_A(ma, ia, ba, na) & 
!      +1.0d0 * t1_A(ma, ba) * t1_A(ia, na) & 
!      -1.0d0 * t1_A(ib, bb) * t1_A(ma, na) & 
!      +1.0d0 * t1_A(ia, ba) * t1_A(ma, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(ib,ma,aa,mb) = M2_A(ib,ma,aa,mb) & 
!      +1.0d0 * t2_A(ia, nb, na, ab) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,ja,na,bb) = M2_A(nb,ja,na,bb) & 
!      +1.0d0 * t2_A(ma, jb, ba, mb) & 
!      +1.0d0 * t1_A(ma, ba) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do aa = i_aa, f_aa
!      if (aa == na) cycle 
!      ab = aa + cc_nVa
!      M2_A(nb,ja,aa,mb) = M2_A(nb,ja,aa,mb) & 
!      +1.0d0 * t2_A(nb, jb, ab, mb) & 
!      +1.0d0 * t1_A(nb, ab) * t1_A(jb, mb) & 
!      -1.0d0 * t1_A(ja, aa) * t1_A(nb, mb) & 
!      +1.0d0 * t1_A(jb, ab) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja), (nb, ib))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,ma,aa,bb) = M2_A(nb,ma,aa,bb) & 
!      -1.0d0 * t2_A(ma, nb, ba, ab) & 
!      -1.0d0 * t1_A(nb, ab) * t1_A(ma, ba)
!    enddo
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M2_A(ib,ma,na,mb) = M2_A(ib,ma,na,mb) & 
!    +1.0d0 * t1_A(ia, na)
!  enddo
!
!  !! Deltas:((na, aa), (mb, bb), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    M2_A(nb,ja,na,mb) = M2_A(nb,ja,na,mb) & 
!    +1.0d0 * t1_A(jb, mb)
!  enddo
!
!  !! Deltas:((na, aa), (ma, ja), (nb, ib))
!  do bb = i_bb, f_bb
!    if (bb == mb) cycle 
!    ba = bb - cc_nVa
!    M2_A(nb,ma,na,bb) = M2_A(nb,ma,na,bb) & 
!    -1.0d0 * t1_A(ma, ba)
!  enddo
!
!  !! Deltas:((mb, bb), (ma, ja), (nb, ib))
!  do aa = i_aa, f_aa
!    if (aa == na) cycle 
!    ab = aa + cc_nVa
!    M2_A(nb,ma,aa,mb) = M2_A(nb,ma,aa,mb) & 
!    -1.0d0 * t1_A(nb, ab)
!  enddo
!
!  ! ### Spin case: i_b, j_a, a_b, b_a ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do ba = i_ba, f_ba
!          if (ba == na) cycle 
!          bb = ba + cc_nVa
!          M2_A(ib,ja,ab,ba) = M2_A(ib,ja,ab,ba) & 
!          -1.0d0 * t2_A(ma, jb, aa, bb) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t2_A(ia, nb, aa, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, nb, aa, bb) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t2_A(ma, ia, aa, na) * t2_A(nb, jb, bb, mb) & 
!          -1.0d0 * t2_A(ia, jb, aa, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t2_A(ma, jb, aa, mb) * t2_A(ia, nb, na, bb) & 
!          +1.0d0 * t2_A(ia, nb, aa, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ia, jb, na, bb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t2_A(ia, jb, na, mb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(jb, mb) * t2_A(ia, nb, na, bb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(nb, mb) * t2_A(ia, jb, na, bb) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(ia, na) * t2_A(ma, jb, aa, mb) & 
!          -1.0d0 * t1_A(nb, bb) * t1_A(ma, na) * t2_A(ia, jb, aa, mb) & 
!          +1.0d0 * t1_A(nb, bb) * t1_A(jb, mb) * t2_A(ma, ia, aa, na) & 
!          +1.0d0 * t1_A(ia, na) * t1_A(jb, mb) * t2_A(ma, nb, aa, bb) & 
!          -1.0d0 * t1_A(ia, na) * t1_A(nb, mb) * t2_A(ma, jb, aa, bb) & 
!          -1.0d0 * t1_A(ma, na) * t1_A(jb, mb) * t2_A(ia, nb, aa, bb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ia, na) * t1_A(jb, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ma, na) * t2_A(nb, jb, bb, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(nb, mb) * t2_A(ma, jb, na, bb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(jb, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ma, na) * t2_A(ia, nb, aa, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(nb, mb) * t2_A(ma, ia, aa, na) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t1_A(ia, na) * t1_A(nb, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t2_A(ma, jb, na, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ma, na) * t2_A(nb, jb, bb, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(jb, mb) * t2_A(ma, nb, na, bb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(nb, mb) * t2_A(ma, jb, na, bb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t1_A(ma, na) * t1_A(jb, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ma, na) * t2_A(ia, nb, aa, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(nb, mb) * t2_A(ma, ia, aa, na) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t1_A(ia, na) * t1_A(nb, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ib,ja,mb,ba) = M2_A(ib,ja,mb,ba) & 
!        +1.0d0 * t1_A(nb, bb) * t2_A(ia, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(nb, jb, bb, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ia, nb, na, bb) & 
!        -1.0d0 * t1_A(nb, mb) * t2_A(ia, jb, na, bb) & 
!        +1.0d0 * t1_A(nb, bb) * t1_A(ia, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ib,ja,ab,na) = M2_A(ib,ja,ab,na) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ia, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ma, jb, aa, mb) & 
!        -1.0d0 * t1_A(ma, na) * t2_A(ia, jb, aa, mb) & 
!        +1.0d0 * t1_A(jb, mb) * t2_A(ma, ia, aa, na) & 
!        +1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t1_A(jb, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ma, jb, na, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t1_A(ma, na) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ma, jb, na, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t1_A(ma, na) * t1_A(jb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(ib,ma,ab,ba) = M2_A(ib,ma,ab,ba) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, na, bb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, ia, aa, na) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ma, nb, aa, bb) & 
!        +1.0d0 * t1_A(ma, na) * t2_A(ia, nb, aa, bb) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(ia, na) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, na, bb) & 
!        +1.0d0 * t1_A(ib, ab) * t1_A(nb, bb) * t1_A(ma, na) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, na, bb) & 
!        -1.0d0 * t1_A(ia, aa) * t1_A(nb, bb) * t1_A(ma, na)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do ba = i_ba, f_ba
!        if (ba == na) cycle 
!        bb = ba + cc_nVa
!        M2_A(nb,ja,ab,ba) = M2_A(nb,ja,ab,ba) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(nb, jb, bb, mb) & 
!        -1.0d0 * t1_A(nb, bb) * t2_A(ma, jb, aa, mb) & 
!        -1.0d0 * t1_A(jb, mb) * t2_A(ma, nb, aa, bb) & 
!        +1.0d0 * t1_A(nb, mb) * t2_A(ma, jb, aa, bb) & 
!        -1.0d0 * t1_A(ma, aa) * t1_A(nb, bb) * t1_A(jb, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ja = i_ja, f_ja
!      if (ja == ma) cycle 
!      jb = ja + cc_nOa
!      M2_A(ib,ja,mb,na) = M2_A(ib,ja,mb,na) & 
!      +1.0d0 * t2_A(ia, jb, na, mb) & 
!      +1.0d0 * t1_A(ia, na) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(ib,ma,mb,ba) = M2_A(ib,ma,mb,ba) & 
!      -1.0d0 * t2_A(ia, nb, na, bb) & 
!      -1.0d0 * t1_A(nb, bb) * t1_A(ia, na)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ib,ma,ab,na) = M2_A(ib,ma,ab,na) & 
!      -1.0d0 * t2_A(ma, ia, aa, na) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(ia, na) & 
!      +1.0d0 * t1_A(ib, ab) * t1_A(ma, na) & 
!      -1.0d0 * t1_A(ia, aa) * t1_A(ma, na)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(nb,ja,mb,ba) = M2_A(nb,ja,mb,ba) & 
!      -1.0d0 * t2_A(nb, jb, bb, mb) & 
!      -1.0d0 * t1_A(nb, bb) * t1_A(jb, mb) & 
!      +1.0d0 * t1_A(ja, ba) * t1_A(nb, mb) & 
!      -1.0d0 * t1_A(jb, bb) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(nb,ja,ab,na) = M2_A(nb,ja,ab,na) & 
!      -1.0d0 * t2_A(ma, jb, aa, mb) & 
!      -1.0d0 * t1_A(ma, aa) * t1_A(jb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((ma, ja), (nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    do ba = i_ba, f_ba
!      if (ba == na) cycle 
!      bb = ba + cc_nVa
!      M2_A(nb,ma,ab,ba) = M2_A(nb,ma,ab,ba) & 
!      +1.0d0 * t2_A(ma, nb, aa, bb) & 
!      +1.0d0 * t1_A(ma, aa) * t1_A(nb, bb)
!    enddo
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (ma, ja))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    M2_A(ib,ma,mb,na) = M2_A(ib,ma,mb,na) & 
!    -1.0d0 * t1_A(ia, na)
!  enddo
!
!  !! Deltas:((na, ba), (mb, ab), (nb, ib))
!  do ja = i_ja, f_ja
!    if (ja == ma) cycle 
!    jb = ja + cc_nOa
!    M2_A(nb,ja,mb,na) = M2_A(nb,ja,mb,na) & 
!    -1.0d0 * t1_A(jb, mb)
!  enddo
!
!  !! Deltas:((mb, ab), (ma, ja), (nb, ib))
!  do ba = i_ba, f_ba
!    if (ba == na) cycle 
!    bb = ba + cc_nVa
!    M2_A(nb,ma,mb,ba) = M2_A(nb,ma,mb,ba) & 
!    +1.0d0 * t1_A(nb, bb)
!  enddo
!
!  !! Deltas:((na, ba), (ma, ja), (nb, ib))
!  do ab = i_ab, f_ab
!    if (ab == mb) cycle 
!    aa = ab - cc_nVa
!    M2_A(nb,ma,ab,na) = M2_A(nb,ma,ab,na) & 
!    +1.0d0 * t1_A(ma, aa)
!  enddo
!
!  ! ### Spin case: i_b, j_b, a_b, b_b ###
!
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        do bb = i_bb, f_bb
!          if (bb == mb) cycle 
!          ba = bb - cc_nVa
!          M2_A(ib,jb,ab,bb) = M2_A(ib,jb,ab,bb) & 
!          -1.0d0 * t2_A(ma, ja, aa, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t2_A(ma, ia, aa, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t2_A(ia, ja, aa, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t2_A(ma, ja, aa, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t2_A(ma, ia, aa, na) * t2_A(ja, nb, ba, mb) & 
!          +1.0d0 * t2_A(ja, nb, aa, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t2_A(ia, nb, aa, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t2_A(ma, nb, aa, mb) * t2_A(ia, ja, ba, na) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(ja, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t1_A(ma, aa) * t1_A(ia, na) * t2_A(ja, nb, ba, mb) & 
!          +1.0d0 * t1_A(ma, aa) * t1_A(nb, mb) * t2_A(ia, ja, ba, na) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(ja, na) * t2_A(ia, nb, aa, mb) & 
!          +1.0d0 * t1_A(ma, ba) * t1_A(ia, na) * t2_A(ja, nb, aa, mb) & 
!          -1.0d0 * t1_A(ma, ba) * t1_A(nb, mb) * t2_A(ia, ja, aa, na) & 
!          +1.0d0 * t1_A(ja, na) * t1_A(nb, mb) * t2_A(ma, ia, aa, ba) & 
!          -1.0d0 * t1_A(ia, na) * t1_A(nb, mb) * t2_A(ma, ja, aa, ba) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ib, ab) * t1_A(ma, na) * t2_A(ja, nb, ba, mb) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(nb, mb) * t2_A(ma, ja, ba, na) & 
!          -1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t1_A(ja, na) * t1_A(nb, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(jb, ab) * t1_A(ma, na) * t2_A(ia, nb, ba, mb) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(nb, mb) * t2_A(ma, ia, ba, na) & 
!          +1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t1_A(ia, na) * t1_A(nb, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(ib, bb) * t1_A(ma, na) * t2_A(ja, nb, aa, mb) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(nb, mb) * t2_A(ma, ja, aa, na) & 
!          +1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t1_A(ja, na) * t1_A(nb, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(jb, bb) * t1_A(ma, na) * t2_A(ia, nb, aa, mb) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(nb, mb) * t2_A(ma, ia, aa, na) & 
!          -1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t1_A(ia, na) * t1_A(nb, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t2_A(ja, nb, na, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t2_A(ma, nb, ba, mb) & 
!          -1.0d0 * t1_A(ia, aa) * t1_A(ma, na) * t2_A(ja, nb, ba, mb) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(nb, mb) * t2_A(ma, ja, ba, na) & 
!          +1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t1_A(ja, na) * t1_A(nb, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t2_A(ia, nb, na, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t2_A(ma, nb, ba, mb) & 
!          +1.0d0 * t1_A(ja, aa) * t1_A(ma, na) * t2_A(ia, nb, ba, mb) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(nb, mb) * t2_A(ma, ia, ba, na) & 
!          -1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t1_A(ia, na) * t1_A(nb, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t2_A(ja, nb, na, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t2_A(ma, nb, aa, mb) & 
!          +1.0d0 * t1_A(ia, ba) * t1_A(ma, na) * t2_A(ja, nb, aa, mb) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(nb, mb) * t2_A(ma, ja, aa, na) & 
!          -1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t1_A(ja, na) * t1_A(nb, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t2_A(ia, nb, na, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t2_A(ma, nb, aa, mb) & 
!          -1.0d0 * t1_A(ja, ba) * t1_A(ma, na) * t2_A(ia, nb, aa, mb) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(nb, mb) * t2_A(ma, ia, aa, na) & 
!          +1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t1_A(ia, na) * t1_A(nb, mb)
!        enddo
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,jb,mb,bb) = M2_A(ib,jb,mb,bb) & 
!        +1.0d0 * t1_A(ja, na) * t2_A(ia, nb, ba, mb) & 
!        -1.0d0 * t1_A(ia, na) * t2_A(ja, nb, ba, mb) & 
!        +1.0d0 * t1_A(nb, mb) * t2_A(ia, ja, ba, na) & 
!        +1.0d0 * t1_A(ib, bb) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ib, bb) * t1_A(ja, na) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(jb, bb) * t1_A(ia, na) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ia, ba) * t1_A(ja, na) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(ja, ba) * t1_A(ia, na) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do jb = i_jb, f_jb
!      if (jb == nb) cycle 
!      ja = jb - cc_nOa
!      do ab = i_ab, f_ab
!        if (ab == mb) cycle 
!        aa = ab - cc_nVa
!        M2_A(ib,jb,ab,mb) = M2_A(ib,jb,ab,mb) & 
!        -1.0d0 * t1_A(ja, na) * t2_A(ia, nb, aa, mb) & 
!        +1.0d0 * t1_A(ia, na) * t2_A(ja, nb, aa, mb) & 
!        -1.0d0 * t1_A(nb, mb) * t2_A(ia, ja, aa, na) & 
!        -1.0d0 * t1_A(ib, ab) * t2_A(ja, nb, na, mb) & 
!        -1.0d0 * t1_A(ib, ab) * t1_A(ja, na) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t2_A(ia, nb, na, mb) & 
!        +1.0d0 * t1_A(jb, ab) * t1_A(ia, na) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t2_A(ja, nb, na, mb) & 
!        +1.0d0 * t1_A(ia, aa) * t1_A(ja, na) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t2_A(ia, nb, na, mb) & 
!        -1.0d0 * t1_A(ja, aa) * t1_A(ia, na) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(ib,nb,ab,bb) = M2_A(ib,nb,ab,bb) & 
!        -1.0d0 * t1_A(ma, aa) * t2_A(ia, nb, ba, mb) & 
!        +1.0d0 * t1_A(ma, ba) * t2_A(ia, nb, aa, mb) & 
!        -1.0d0 * t1_A(nb, mb) * t2_A(ma, ia, aa, ba) & 
!        +1.0d0 * t1_A(ib, ab) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(ib, ab) * t1_A(ma, ba) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(ib, bb) * t1_A(ma, aa) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(ia, aa) * t1_A(ma, ba) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(ia, ba) * t1_A(ma, aa) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      do bb = i_bb, f_bb
!        if (bb == mb) cycle 
!        ba = bb - cc_nVa
!        M2_A(nb,jb,ab,bb) = M2_A(nb,jb,ab,bb) & 
!        +1.0d0 * t1_A(ma, aa) * t2_A(ja, nb, ba, mb) & 
!        -1.0d0 * t1_A(ma, ba) * t2_A(ja, nb, aa, mb) & 
!        +1.0d0 * t1_A(nb, mb) * t2_A(ma, ja, aa, ba) & 
!        -1.0d0 * t1_A(jb, ab) * t2_A(ma, nb, ba, mb) & 
!        -1.0d0 * t1_A(jb, ab) * t1_A(ma, ba) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t2_A(ma, nb, aa, mb) & 
!        +1.0d0 * t1_A(jb, bb) * t1_A(ma, aa) * t1_A(nb, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t2_A(ma, nb, ba, mb) & 
!        +1.0d0 * t1_A(ja, aa) * t1_A(ma, ba) * t1_A(nb, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t2_A(ma, nb, aa, mb) & 
!        -1.0d0 * t1_A(ja, ba) * t1_A(ma, aa) * t1_A(nb, mb)
!      enddo
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(ib,nb,mb,bb) = M2_A(ib,nb,mb,bb) & 
!      -1.0d0 * t2_A(ia, nb, ba, mb) & 
!      -1.0d0 * t1_A(ib, bb) * t1_A(nb, mb) & 
!      +1.0d0 * t1_A(ia, ba) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, jb))
!  do ib = i_ib, f_ib
!    if (ib == nb) cycle 
!    ia = ib - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(ib,nb,ab,mb) = M2_A(ib,nb,ab,mb) & 
!      +1.0d0 * t2_A(ia, nb, aa, mb) & 
!      +1.0d0 * t1_A(ib, ab) * t1_A(nb, mb) & 
!      -1.0d0 * t1_A(ia, aa) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, ab), (nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do bb = i_bb, f_bb
!      if (bb == mb) cycle 
!      ba = bb - cc_nVa
!      M2_A(nb,jb,mb,bb) = M2_A(nb,jb,mb,bb) & 
!      +1.0d0 * t2_A(ja, nb, ba, mb) & 
!      +1.0d0 * t1_A(jb, bb) * t1_A(nb, mb) & 
!      -1.0d0 * t1_A(ja, ba) * t1_A(nb, mb)
!    enddo
!  enddo
!
!  !! Deltas:((mb, bb), (nb, ib))
!  do jb = i_jb, f_jb
!    if (jb == nb) cycle 
!    ja = jb - cc_nOa
!    do ab = i_ab, f_ab
!      if (ab == mb) cycle 
!      aa = ab - cc_nVa
!      M2_A(nb,jb,ab,mb) = M2_A(nb,jb,ab,mb) & 
!      -1.0d0 * t2_A(ja, nb, aa, mb) & 
!      -1.0d0 * t1_A(jb, ab) * t1_A(nb, mb) & 
!      +1.0d0 * t1_A(ja, aa) * t1_A(nb, mb)
!    enddo
!  enddo
!
!end

! Extract open orb spin

subroutine extract_open_spin_orb(nO,nV,det,m,mb,n,nb)

  implicit none

  integer, intent(in)           :: nO,nV
  integer(bit_kind), intent(in) :: det(N_int,2)

  integer, intent(out)          :: m,mb,n,nb

  integer                       :: i
  integer                       :: idx_o, idx_v, s
  integer(bit_kind)             :: res(N_int,2)
  integer                       :: list_o(4)
  logical                       :: is_pa, is_pb, is_core, is_del

  !if (n_core_orb > 0) then
  !   print*,'Not implemented for frozen core, abort'
  !   call abort
  !endif
  
  ! List of open orbitals
  idx_o = 1
  idx_v = 1
  do s = 1, 2
    do i = 1, mo_num
      if (is_core(i)) cycle
      if (is_del(i)) cycle
      call apply_hole(det, 1, i, res, is_pa, N_int)
      call apply_hole(det, 2, i, res, is_pb, N_int)

      if ((s == 1 .and. is_pa) .or. (s == 2 .and. is_pb)) then
        idx_o = idx_o + 1
      elseif ((s == 1 .and. .not. is_pa) .or. (s == 2 .and. .not. is_pb)) then
        idx_v = idx_v + 1
      endif
      
      if     (s == 1  .and.     is_pa     .and.  .not. is_pb) then
        list_o(1) = idx_o-1
      elseif (s == 1  .and.  .not. is_pa  .and.    is_pb    ) then
        list_o(2) = idx_v-1 
      elseif (s == 2  .and.  .not. is_pa  .and.    is_pb    ) then
        list_o(3) = idx_o-1
      elseif (s == 2  .and.     is_pa     .and.  .not. is_pb) then
        list_o(4) = idx_v-1
      endif
    enddo
  enddo

  ! Ref:
  
  !nOa = nO / 2
  !nVa = nV / 2

  ! T1
  !              a
  !       1 ... nVa ... nV
  !    1         |
  !    :   aa    |   ab 
  !    :         |
  ! i nOa -------|---------
  !    :         |
  !    :   ba    |   bb
  !   nO         |
  
  !   a     n     m     i
  !   |    -|->   |    -|->
  !   |     |   <-|-  <-|-
  m  = list_o(1)
  nb = list_o(3)
  n  = list_o(2)
  mb = list_o(4)

  ! Reminder: -The index of i_beta (ib) is i_alpha (i) + number of occupied alpha (nOa)
  !           -The index of a_beta (ab) is a_alpha (a) + number of virtual alpha (nVa)
  !           -Cycle when i == m and a == n to avoid considering an
  ! open MO as a core or virtual one
  
end
