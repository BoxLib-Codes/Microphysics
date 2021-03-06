module microphysics_module

  use network
  use eos_module, only : eos_init
#ifdef REACTIONS
#ifndef NETWORK_HAS_CXX_IMPLEMENTATION
#ifndef TRUE_SDC
  use actual_rhs_module, only : actual_rhs_init
#endif
#endif
#endif

#ifdef CONDUCTIVITY
  use actual_conductivity_module, only: actual_conductivity_init
#endif

  use amrex_fort_module, only : rt => amrex_real
  implicit none

contains

  subroutine microphysics_initialize(small_temp, small_dens) bind(C, name="microphysics_initialize")
    ! this version has no optional arguments so was can bind to C

    real(rt), intent(in), value :: small_temp, small_dens

    call microphysics_init(small_temp, small_dens)

  end subroutine microphysics_initialize

  subroutine microphysics_init(small_temp, small_dens)

    real(rt), optional, intent(in) :: small_temp
    real(rt), optional, intent(in) :: small_dens

    call network_init()

    if (present(small_temp) .and. present(small_dens)) then
       call eos_init(small_temp=small_temp, small_dens=small_dens)
    else if (present(small_temp)) then
       call eos_init(small_temp=small_temp)
    else if (present(small_dens)) then
       call eos_init(small_dens=small_dens)
    else
       call eos_init()
    endif

#ifdef REACTIONS
#ifndef NETWORK_HAS_CXX_IMPLEMENTATION
#ifndef TRUE_SDC
    call actual_rhs_init()
#endif
#endif
#endif

#ifdef CONDUCTIVITY
    call actual_conductivity_init()
#endif

  end subroutine microphysics_init

  subroutine microphysics_finalize() bind(C, name="microphysics_finalize")

    use eos_module, only: eos_finalize
#ifdef USE_SCREENING
    use screening_module, only: screening_finalize
    call screening_finalize()
#endif

    call eos_finalize()
    call network_finalize()

  end subroutine microphysics_finalize

end module microphysics_module

