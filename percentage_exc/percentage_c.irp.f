

! Provided
! | max_exc_degree    | integer | maximum excitation degree        |
! | percentage_in_exp | logical | to use or not exponential format |

! internal
! | percentage(max_exc_degree+1,N_states) | double precision | The ith element is the percentage of |
! |                                       |                  | the i-1 coefficients/excitations     |
! | list_states(N_states)                 | integer          | list of states                       |
! | accu(N_states)                        | double precision | temporary array                      |
! | exc                                   | character        | excitation degree                    |


subroutine run_print_percentage_c

  implicit none

  integer :: i,s
  integer, allocatable :: list_states(:)
  double precision, allocatable :: percentage(:,:), accu(:)
  character(len=2) :: exc

  allocate(percentage(max_exc_degree+1, n_states), accu(n_states), list_states(n_states))

  call percentage_c(percentage)
  
  do s = 1, n_states
   list_states(s) = s
  enddo   

  print*,''
  print*,'Percentage of the excitations per state:'
  write(*,'(A4,10(I12))') '', list_states(:)
  if (percentage_in_exp) then
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(1pE12.4))') '%C', adjustl(exc), percentage(i,:)
    enddo
  else
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(F12.4))') '%C', adjustl(exc), percentage(i,:)
    enddo
  endif

  print*,''
  print*,'Percentage of the excitations'
  print*,'in intermediate normalization, %C0=1:'
  write(*,'(A4,10(I12))') '', 1
  if (percentage_in_exp) then
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(1pE12.4))') '%C', adjustl(exc), percentage(i,:)/percentage(1,:)
    enddo
  else
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(F12.4))') '%C', adjustl(exc), percentage(i,:)/percentage(1,:)
    enddo
  endif

  print*,''
  print*,'Sum of the contributions per state:'
  write(*,'(A4,10(I12))') '', list_states(:)
  accu = 0d0
  if (percentage_in_exp) then
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      do s = 1, n_states
        accu(s) = accu(s) + percentage(i,s)
      enddo
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(1pE12.4))') '%C', adjustl(exc), accu(:)
    enddo
  else
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      do s = 1, n_states
        accu(s) = accu(s) + percentage(i,s)
      enddo
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(F12.4))') '%C', adjustl(exc), accu(:)
    enddo
  endif

  print*,''
  print*,'Missing contributions per state:'
  write(*,'(A4,10(I12))') '', list_states(:)
  if (percentage_in_exp) then
    accu = 0d0
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      do s = 1, n_states
        accu(s) = accu(s) + percentage(i,s)
      enddo
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(1pE12.4))') '%C', adjustl(exc), 100d0-accu(:)        
    enddo
  else
    accu = 0d0
    do i = 1, min(max_exc_degree+1,nb_max_percentage)
      do s = 1, n_states
        accu(s) = accu(s) + percentage(i,s)
      enddo
      write (exc,'(I2)') i-1
      write (*, '(A2,A2,10(F12.4))') '%C', adjustl(exc), 100d0-accu(:)        
    enddo
  endif

  deallocate(percentage, accu, list_states)

end

! Calculation of the percentages

! \begin{equation}
! C_i = \sum_i c_i^2
! \end{equation}

! Provided
! | N_states                 | integer            | number of states          |
! | max_exc_degree           | integer            | maximum excitation degree |
! | HF_bitmask               | integer(bitstring) | HF determinants           |
! | psi_det(N_int,2,N_det)   | integer(bitstring) | Determinants              |
! | psi_coef(N_det,N_states) | double precision   | CI coefficients           |
! | N_int                    | integer            | Number of int per det     |
! | N_det                    | integer            | Number of det             |

! Out
! | percentage(max_exc_degree + 1, n_states) | double precision | The ith element is the percentage of |
! |                                          |                  | the i-1 coefficients/excitations     |

! Internal
! | exc_degree | integer | excitation degree              |
! | idx_hf     | integer | index of the HF det in psi_det |
! | i,s        | integer | dummy indexes                  |


subroutine percentage_c(percentage)

  implicit none

  ! out
  double precision, intent(out) :: percentage(max_exc_degree + 1, N_states) 

  ! internal
  integer :: i, s, degree, idx_hf

  percentage = 0d0

  ! %C(n,s_state) = \sum_i psi_coef(i,s)**2 s.t. excitation_degree(|HF>,|i>) = n

  ! Contribution of HF det
  call find_hf(psi_det,N_det,N_int,idx_hf)
  do s = 1, N_states
    percentage(1,s) = psi_coef(idx_hf,s)**2
  enddo
  
  ! Others determinants
  do i = 1, N_det
    call get_excitation_degree(HF_bitmask, psi_det(1,1,i), degree, n_int)
    if (degree == 0) then
      cycle
    endif
    do s = 1, N_states
      percentage(degree+1, s) = percentage(degree+1, s) + psi_coef(i,s)**2
    enddo
  enddo

  percentage = percentage *100d0

end
