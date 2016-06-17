module integrator_module

  implicit none

  public

contains

  subroutine integrator_init()

    use actual_integrator_module, only: actual_integrator_init
    use integration_data, only: temp_scale, ener_scale, dens_scale, inv_temp_scale, inv_ener_scale, inv_dens_scale, aionInv
    use actual_network, only: nspec, aion
    use bl_constants_module, only: ONE

    implicit none

    call actual_integrator_init()

    inv_temp_scale = ONE / temp_scale
    inv_dens_scale = ONE / dens_scale
    inv_ener_scale = ONE / ener_scale

    !$acc update device(temp_scale, ener_scale, dens_scale)

    aionInv = ONE / aion

    !$acc update device(aionInv)

  end subroutine integrator_init



  subroutine integrator(state_in, state_out, dt, time)

    !$acc routine seq

    use actual_integrator_module, only: actual_integrator
    use bl_error_module, only: bl_error
    use burn_type_module, only: burn_t
    use bl_types, only: dp_t

    implicit none

    type (burn_t),  intent(in   ) :: state_in
    type (burn_t),  intent(inout) :: state_out
    real(dp_t),     intent(in   ) :: dt, time

    call actual_integrator(state_in, state_out, dt, time)

  end subroutine integrator

end module integrator_module
