module reaclib_rates

  use amrex_fort_module, only: rt => amrex_real
  use screening_module, only: add_screening_factor, &
                              screening_init, screening_finalize, &
                              plasma_state, fill_plasma_state
  use network

  implicit none

  logical, parameter :: screen_reaclib = .true.

  ! Temperature coefficient arrays (numbers correspond to reaction numbers in net_info)
  real(rt), allocatable :: ctemp_rate(:,:)

  ! Index into ctemp_rate, dimension 2, where each rate's coefficients start
  integer, allocatable :: rate_start_idx(:)

  ! Reaction multiplicities-1 (how many rates contribute - 1)
  integer, allocatable :: rate_extra_mult(:)

#ifdef AMREX_USE_CUDA
  attributes(managed) :: ctemp_rate, rate_start_idx, rate_extra_mult
#endif

contains

  subroutine init_reaclib()

    implicit none

    integer :: unit, ireaclib, icoeff

    allocate( ctemp_rate(7, number_reaclib_sets) )
    allocate( rate_start_idx(nrat_reaclib) )
    allocate( rate_extra_mult(nrat_reaclib) )

    open(newunit=unit, file='reaclib_rate_metadata.dat')

    do ireaclib = 1, number_reaclib_sets
       do icoeff = 1, 7
          read(unit, *) ctemp_rate(icoeff, ireaclib)
       enddo
    enddo

    do ireaclib = 1, nrat_reaclib
       read(unit, *) rate_start_idx(ireaclib)
    enddo

    do ireaclib = 1, nrat_reaclib
       read(unit, *) rate_extra_mult(ireaclib)
    enddo

    close(unit)

  end subroutine init_reaclib

  subroutine term_reaclib()
    deallocate( ctemp_rate )
    deallocate( rate_start_idx )
    deallocate( rate_extra_mult )
  end subroutine term_reaclib


  subroutine net_screening_init()
    ! Adds screening factors and calls screening_init

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jc12), aion(jc12))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jc12), aion(jc12))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jc14), aion(jc14))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jn14), aion(jn14))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jo16), aion(jo16))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jne20), aion(jne20))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jmg24), aion(jmg24))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jal27), aion(jal27))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jal27), aion(jal27))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jsi28), aion(jsi28))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jp31), aion(jp31))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jp31), aion(jp31))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(js32), aion(js32))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jcl35), aion(jcl35))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jcl35), aion(jcl35))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jar36), aion(jar36))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jk39), aion(jk39))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jk39), aion(jk39))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jca40), aion(jca40))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jsc43), aion(jsc43))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jsc43), aion(jsc43))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jti44), aion(jti44))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jv47), aion(jv47))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jv47), aion(jv47))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jcr48), aion(jcr48))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jmn51), aion(jmn51))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jmn51), aion(jmn51))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jfe52), aion(jfe52))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jco55), aion(jco55))

    call add_screening_factor(zion(jc12), aion(jc12), &
      zion(jc12), aion(jc12))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jn13), aion(jn13))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jo16), aion(jo16))

    call add_screening_factor(zion(jc12), aion(jc12), &
      zion(jo16), aion(jo16))

    call add_screening_factor(zion(jo16), aion(jo16), &
      zion(jo16), aion(jo16))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jf18), aion(jf18))

    call add_screening_factor(zion(jc12), aion(jc12), &
      zion(jne20), aion(jne20))

    call add_screening_factor(zion(jp), aion(jp), &
      zion(jne21), aion(jne21))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      zion(jhe4), aion(jhe4))

    call add_screening_factor(zion(jhe4), aion(jhe4), &
      4.0_rt, 8.0_rt)


    call screening_init()
  end subroutine net_screening_init


  subroutine net_screening_finalize()
    ! Call screening_finalize

    call screening_finalize()

  end subroutine net_screening_finalize


  subroutine reaclib_evaluate(pstate, temp, iwhich, rate, drate_dt)

    implicit none

    type(plasma_state), intent(in) :: pstate
    real(rt), intent(in) :: temp
    integer, intent(in) :: iwhich

    real(rt), intent(out) :: rate     ! Reaction rate
    real(rt), intent(out) :: drate_dt ! Reaction rate temperature derivative

    real(rt) :: ri, T9, T9_exp, lnirate, irate, dirate_dt, dlnirate_dt
    integer :: i, j, m, istart

    ri = 0.0e0_rt
    rate = 0.0e0_rt
    drate_dt = 0.0e0_rt
    irate = 0.0e0_rt
    dirate_dt = 0.0e0_rt
    T9 = temp/1.0e9_rt
    T9_exp = 0.0e0_rt

    ! Get the number of additional Reaclib sets for this rate
    ! Total number of Reaclib sets for this rate is m + 1
    m = rate_extra_mult(iwhich)

    istart = rate_start_idx(iwhich)

    do i = 0, m
       lnirate = ctemp_rate(1, istart+i) + ctemp_rate(7, istart+i) * LOG(T9)
       dlnirate_dt = ctemp_rate(7, istart+i)/T9
       do j = 2, 6
          T9_exp = (2.0e0_rt*dble(j-1)-5.0e0_rt)/3.0e0_rt
          lnirate = lnirate + ctemp_rate(j, istart+i) * T9**T9_exp
          dlnirate_dt = dlnirate_dt + &
               T9_exp * ctemp_rate(j, istart+i) * T9**(T9_exp-1.0e0_rt)
       end do
       ! If the rate will be in the approx. interval [0.0, 1.0E-100], replace by 0.0
       ! This avoids issues with passing very large negative values to EXP
       ! and getting results between 0.0 and 1.0E-308, the limit for IEEE 754.
       ! And avoids SIGFPE in CVODE due to tiny rates.
       lnirate = max(lnirate, -230.0e0_rt)
       irate = EXP(lnirate)
       rate = rate + irate
       dirate_dt = irate * dlnirate_dt/1.0e9_rt
       drate_dt = drate_dt + dirate_dt
    end do

  end subroutine reaclib_evaluate

end module reaclib_rates
