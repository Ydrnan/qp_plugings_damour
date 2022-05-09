subroutine run_print_percentage_t

  implicit none

  integer :: i,s, nb_T
  integer, allocatable :: list_states(:)
  double precision, allocatable :: percentage(:,:), accu(:)

  nb_T = 3
  allocate(percentage(nb_T, n_states), accu(n_states), list_states(n_states))

  call percentage_t(nb_T,percentage)
  
  do s = 1, n_states
   list_states(s) = s
  enddo   

  print*,''
  print*,'Percentage of the excitations per state:'
  write(*,'(A4,10(I12))') '', list_states(:)
  do i = 1, nb_T
    !write (exc, '(i4)') i-1
    write (*, '(A2,I2,10(1pE12.4))') '%T', i-1, percentage(i,:)    
  enddo

  print*,''
  print*,'Sum of the contributions per state:'
  write(*,'(A4,10(I12))') '', list_states(:)
  accu = 0d0
  do i = 1, nb_T
    do s = 1, n_states
      accu(s) = accu(s) + percentage(i,s)
    enddo
    write (*, '(A2,I2,10(F12.4))') '%T', i-1, accu(:)
  enddo

  print*,''
  print*,'Missing contributions per state:'
  write(*,'(A4,10(I12))') '', list_states(:)
  accu = 0d0
  do i = 1, nb_T
    do s = 1, n_states
      accu(s) = accu(s) + percentage(i,s)
    enddo
    write (*, '(A2,I2,10(1pE12.4))') '%T', i-1, 100d0-accu(:)        
  enddo

  deallocate(percentage, accu, list_states)

end

subroutine percentage_t(nb_T,percentage)

  implicit none

  ! in
  integer :: nb_T

  ! out
  double precision, intent(out) :: percentage(nb_T, n_states) 

  ! internal
  integer :: i, s, n_occ, n_vir, nb_t1
  double precision, allocatable :: t1_amplitude(:,:), t2_amplitude(:,:,:,:)
  double precision, allocatable :: c1_coef(:)
  integer(bit_kind), allocatable :: c1_det(:,:,:)

  ! function
  double precision :: dnrm2

  n_occ = elec_alpha_num + elec_beta_num
  n_vir = 2*mo_num - n_occ

  allocate(t1_amplitude(n_occ,n_vir))
  allocate(t2_amplitude(n_occ,n_occ,n_vir,n_vir))

  percentage = 0d0

  ! %T_0 
  do s = 1, n_states
    percentage(1,s) = psi_coef(1,s)**2
  enddo
  
  ! %T1
  ! t_i^a = c_i^a, %T1 = \sum t1^2
  do s = 1, 1!N_states
    call ci_coef_to_t1(s, n_occ, n_vir, nb_t1, t1_amplitude)
    percentage(2,s) = dnrm2(n_occ * n_vir, t1_amplitude, 1)**2
  enddo
  
  allocate(c1_coef(nb_t1), c1_det(N_int,2,nb_t1))

  !call t1_to_c1(n_occ,n_vir,t1_amplitude,nb_t1,c1_coef,c1_det)

  ! %T2
  do s = 1, N_states
    call ci_coef_to_t2(s, n_occ, n_vir, t1_amplitude, t2_amplitude)
    percentage(3,s) = dnrm2(n_occ*n_occ * n_vir*n_vir, t2_amplitude, 1)**2
  enddo

  ! Frac to %
  percentage = percentage * 100d0

  deallocate(t1_amplitude,t2_amplitude)
  deallocate(c1_coef,c1_det)

end

subroutine ci_coef_to_t1(state, n_occ, n_vir, nb_t1, t1_amplitude)

  implicit none

  ! in 
  integer, intent(in) :: state, n_occ, n_vir

  ! out 
  double precision, intent(out) :: t1_amplitude(n_occ,n_vir)
  integer, intent(out) :: nb_t1

  ! internal
  integer :: i,h1,p1,s1,h2,p2,s2
  integer :: degree, exc(0:2,2,2)
  double precision :: phase

  t1_amplitude = 0d0

  nb_t1 = 0
  do i = 2, N_det
    call get_excitation(psi_det(N_int,1,1),psi_det(N_int,1,i),exc,degree,phase,N_int)
    if (degree == 1) then
      call decode_exc(exc,degree,h1,p1,h2,p2,s1,s2)
      ! alpha
      if (s1==1) then
        t1_amplitude(h1,p1) = psi_coef(i,state)*phase
      ! beta
      else
        t1_amplitude(h1+elec_alpha_num, p1+mo_num-2*elec_alpha_num) = psi_coef(i,state)*phase
      endif
      nb_t1 = nb_t1 + 1
    endif    
  enddo

end

!subroutine t1_to_c1(n_occ,n_vir,t1_amplitude,nb_c1,c1_coef,c1_det)
!
!  implicit none
!
!  ! in 
!  integer, intent(in) :: n_occ, n_vir, nb_c1
!  double precision, intent(in) :: t1_amplitude(n_occ,n_vir)
!
!  ! out 
!  double precision, intent(out) :: c1_coef(nb_c1)
!  integer(bit_kind), intent(out) :: c1_det(N_int,2,nb_c1)
!
!  ! internal 
!  integer :: i,j,a,b,u,sa,si
!  integer :: sigma,h1,p1,s1,h2,p2,s2
!  integer(bit_kind), allocatable :: res(:,:)
!  logical :: ok
!
!  allocate(res(N_int,2))
!
!  print*,'nb_c1', nb_c1
!
!  do u = 1, nb_c1
!    c1_det(:,:,u) = psi_det(:,:,1)
!  enddo
!
!  u = 1
!  do a = 1, n_vir
!    if (a > mo_num - elec_alpha_num) then 
!      p1 = a - mo_num+2*elec_alpha_num
!      sa = 2
!    else 
!      p1 = a + elec_alpha_num
!      sa = 1
!    endif
!    do i = 1, n_occ
!      if (i > elec_alpha_num) then 
!        h1 = i - elec_alpha_num
!        si = 2
!      else
!        h1 = i
!        si = 1
!      endif
!      ! Non-existing amplitudes
!      if (sa /= si) then
!        cycle
!      endif
!      s1 = sa
!      if (dabs(t1_amplitude(i,a)) < 1d-15) then
!        cycle
!      endif
!      !print*,u
!      !print*,i,a
!      !print*,h1,p1,s1
!      !call apply_hole(c1_det(1,1,u), s1, h1, res, ok, N_int)
!      !!call print_det(res,N_int) 
!      !c1_det(:,:,u) = res
!      !call apply_particle(c1_det(1,1,u), s1, p1, res, ok, N_int)
!      !c1_det(:,:,u) = res
!      !call print_det(c1_det(1,1,u),N_int) 
!      u = u + 1
!    enddo
!  enddo  
!
!  deallocate(res)
!
!end

subroutine ci_coef_to_t2(state, n_occ, n_vir, t1_amplitude, t2_amplitude)

  implicit none

  ! in 
  integer, intent(in) :: state, n_occ, n_vir
  double precision, intent(in) :: t1_amplitude(n_occ,n_vir)

  ! out 
  double precision,intent(out) :: t2_amplitude(n_occ,n_occ,n_vir,n_vir)

  ! internal
  integer :: i,j,a,b
  integer :: h1,p1,s1,h2,p2,s2
  integer :: degree, exc(0:2,2,2)
  double precision :: phase
  double precision, allocatable :: c2_coef(:,:,:,:)

  allocate(c2_coef(n_occ,n_occ,n_vir,n_vir))

  c2_coef = 0d0
  t2_amplitude = 0d0

  do i = 2, N_det
    call get_excitation(psi_det(N_int,1,1),psi_det(N_int,1,i),exc,degree,phase,N_int)
    if (degree == 2) then
      call decode_exc(exc,degree,h1,p1,h2,p2,s1,s2)
      ! alpha alpha
      if (s1==1 .and. s2==1) then
        c2_coef(h1,h2,p1,p2) = psi_coef(i,state)*phase
      ! alpha beta
      elseif (s1==1 .and. s2==2) then
        c2_coef(h1,h2+elec_alpha_num,p1,p2+elec_alpha_num) = psi_coef(i,state)*phase
      ! beta alpha
      elseif (s1==2 .and. s2==1) then
        c2_coef(h1+elec_alpha_num,h2,p1+elec_alpha_num,p2) = psi_coef(i,state)*phase
      ! beta beta
      else
        c2_coef(h1+elec_alpha_num,h2+elec_alpha_num,p1+elec_alpha_num,p2+elec_alpha_num) = psi_coef(i,state)*phase
      endif
    endif
  enddo

  do b = 1, n_vir
    do a = 1, n_vir
      do j = 1, n_occ
        do i = 1, n_occ
          t2_amplitude(i,j,a,b) = c2_coef(i,j,a,b) - t1_amplitude(i,a)*t1_amplitude(j,b) + t1_amplitude(i,b)*t1_amplitude(j,a)
        enddo
      enddo
    enddo
  enddo

  deallocate(c2_coef)

end
