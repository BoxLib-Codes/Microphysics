module actual_rhs_module

  use amrex_constants_module
  use amrex_fort_module, only : rt => amrex_real
  use network
  use actual_network
  use burn_type_module
  use rate_type_module

  implicit none

contains

  subroutine actual_rhs_init()

    use screening_module, only: screening_init, add_screening_factor

    implicit none

    call add_screening_factor(zion(ic12),aion(ic12),zion(ic12),aion(ic12))

    call screening_init()

  end subroutine actual_rhs_init

  subroutine get_ebin(density, ebin)

    use amrex_constants_module, only: ZERO
    use fundamental_constants_module

    implicit none

    real(rt)        , intent(in   ) :: density
    real(rt)        , intent(inout) :: ebin(nspec)

    real(rt)         :: rho9, q_eff

    ebin(1:nspec) = ZERO

    ! Chamulak et al. provide the q-value resulting from C12 burning,
    ! given as 3 different values (corresponding to 3 different densities).
    ! Here we do a simple quadratic fit to the 3 values provided (see
    ! Chamulak et al., p. 164, column 2).

    ! our convention is that the binding energies are negative.  We convert
    ! from the MeV values that are traditionally written in astrophysics
    ! papers by multiplying by 1.e6 eV/MeV * 1.60217646e-12 erg/eV.  The
    ! MeV values are per nucleus, so we divide by aion to make it per
    ! nucleon and we multiple by Avogardo's # (6.0221415e23) to get the
    ! value in erg/g
    rho9 = density/1.0e9_rt

    ! q_eff is effective heat evolved per reaction (given in MeV)
    q_eff = 0.06e0_rt*rho9**2 + 0.02e0_rt*rho9 + 8.83e0_rt

    ! convert from MeV to ergs / gram.  Here M12_chamulak is the
    ! number of C12 nuclei destroyed in a single reaction and 12.0 is
    ! the mass of a single C12 nuclei.  Also note that our convention
    ! is that binding energies are negative.
    ebin(ic12) = -q_eff*MeV2eV*eV2erg*n_A/(M12_chamulak*12.0e0_rt)

  end subroutine get_ebin

  subroutine get_rates(state, rr)

    use screening_module, only: screen5, plasma_state, fill_plasma_state

    type (burn_t), intent(in) :: state
    type (rate_t), intent(out) :: rr

    real(rt)         :: temp, T9, T9a, dT9dt, dT9adt

    real(rt)         :: scratch, dscratchdt
    real(rt)         :: rate, dratedt, sc1212, dsc1212dt, dsc1212dd, xc12tmp

    real(rt)         :: dens

    real(rt)         :: a, b, dadt, dbdt

    real(rt)         :: y(nspec)

    real(rt)        , parameter :: FIVE6TH = FIVE / SIX
    integer :: jscr
    type(plasma_state) :: pstate

    temp = state % T
    dens = state % rho

    ! convert mass fractions to molar fractions
    y(1:nspec) = state % xn(1:nspec) * aion_inv(1:nspec)

    ! call the screening routine
    call fill_plasma_state(pstate, temp, dens, y)

    jscr = 1
    call screen5(pstate,jscr,sc1212,dsc1212dt,dsc1212dd)

    ! compute some often used temperature constants
    T9     = temp/1.e9_rt
    dT9dt  = ONE/1.e9_rt
    T9a    = T9/(ONE + 0.0396e0_rt*T9)
    dT9adt = (T9a / T9 - (T9a / (ONE + 0.0396e0_rt*T9)) * 0.0396e0_rt) * dT9dt

    ! compute the CF88 rate
    scratch    = T9a**THIRD
    dscratchdt = THIRD * T9a**(-TWO3RD) * dT9adt

    a       = 4.27e26_rt*T9a**FIVE6TH*T9**(-1.5e0_rt)
    dadt    = FIVE6TH * (a/T9a) * dT9adt - 1.5e0_rt * (a/T9) * dT9dt

    b       = exp(-84.165e0_rt/scratch - 2.12e-3_rt*T9*T9*T9)
    dbdt    = (84.165e0_rt * dscratchdt/ scratch**TWO       &
         - THREE * 2.12e-3_rt * T9 * T9 * dT9dt) * b

    rate    = a *  b
    dratedt = dadt * b + a * dbdt

    ! Save the rate data, for the Jacobian.
    rr % rates(1,:)  = rate
    rr % rates(2,:)  = dratedt
    rr % rates(3,:)  = sc1212
    rr % rates(4,:)  = dsc1212dt

  end subroutine get_rates

  subroutine actual_rhs(state, ydot)

    use extern_probin_module, only: do_constant_volume_burn

    implicit none

    type (burn_t), intent(in)    :: state
    real(rt)        , intent(inout) :: ydot(neqs)
    type (rate_t)    :: rr

    real(rt)         :: temp, xc12tmp, dens
    real(rt)         :: rate, dratedt, sc1212, dsc1212dt

    real(rt)         :: y(nspec), ebin(nspec)

    real(rt)        , parameter :: FIVE6TH = FIVE / SIX

    ydot = ZERO

    call get_rates(state, rr)

    rate = rr % rates(1,1)
    dratedt = rr % rates(2,1)
    sc1212 = rr % rates(3,1)
    dsc1212dt = rr % rates(4,1)

    temp = state % T
    dens = state % rho

    ! we come in with mass fractions -- convert to molar fractions
    y(1:nspec) = state % xn(1:nspec) * aion_inv(1:nspec)


    ! The change in number density of C12 is
    ! d(n12)/dt = - M12_chamulak * 1/2 (n12)**2 <sigma v>
    !
    ! where <sigma v> is the average of the relative velocity times the
    ! cross section for the reaction, and the factor accounting for the
    ! total number of particle pairs has a 1/2 because we are
    ! considering a reaction involving identical particles (see Clayton
    ! p. 293).  Finally, the -M12_chamulak means that for each reaction,
    ! we lose M12_chamulak C12 nuclei (for a single rate, C12+C12,
    ! M12_chamulak would be 2.  In Chamulak et al. (2008), they say a
    ! value of 2.93 captures the energetics from a larger network
    !
    ! Switching over to mass fractions, using n = rho X N_A/A, where N_A is
    ! Avogadro's number, and A is the mass number of the nucleon, we get
    !
    ! d(X12)/dt = -M12_chamulak * 1/2 (X12)**2 rho N_A <sigma v> / A12
    !
    ! The quantity [N_A <sigma v>] is what is tabulated in Caughlin and Fowler.

    xc12tmp = max(y(ic12) * aion(ic12), 0.e0_rt)
    ydot(ic12) = -TWELFTH*HALF*M12_chamulak*dens*sc1212* rate * xc12tmp**2
    ydot(io16) = 0.0_rt
    ydot(iash) = -ydot(ic12)

    ! Convert back to molar form

    ydot(1:nspec) = ydot(1:nspec) * aion_inv(1:nspec)

    call get_ebin(dens, ebin)

    call ener_gener_rate(ydot(1:nspec), ebin, ydot(net_ienuc))

    if (state % self_heat) then

       if (do_constant_volume_burn) then
          ydot(net_itemp) = ydot(net_ienuc) / state % cv

       else
          ydot(net_itemp) = ydot(net_ienuc) / state % cp

       endif
    endif

  end subroutine actual_rhs



  subroutine actual_jac(state, jac)

    use temperature_integration_module, only: temperature_jac

    implicit none

    type (burn_t), intent(in)    :: state
    real(rt)        , intent(inout) :: jac(njrows, njcols)
    type (rate_t)    :: rr

    real(rt)         :: dens
    real(rt)         :: rate, dratedt, scorr, dscorrdt, xc12tmp

    real(rt)         :: ebin(nspec)

    integer          :: j

    jac(:,:)  = ZERO

    ! Get data from the state
    call get_rates(state, rr)

    dens     = state % rho

    rate     = rr % rates(1,1)
    dratedt  = rr % rates(2,1)
    scorr    = rr % rates(3,1)
    dscorrdt = rr % rates(4,1)
    xc12tmp  = max(state % xn(ic12), ZERO)

    ! carbon jacobian elements

    jac(ic12, ic12) = -TWO*TWELFTH*M12_chamulak*HALF*dens*scorr*rate*xc12tmp
    jac(iash, ic12) = -jac(ic12, ic12)

    ! add the temperature derivatives: df(y_i) / dT

    jac(ic12,net_itemp) = -TWELFTH * M12_chamulak * HALF * &
                                   (dens*rate*xc12tmp**2*dscorrdt  &
                                  + dens*scorr*xc12tmp**2*dratedt)

    ! Convert back to molar form

    do j = 1, nspec
       jac(j,:) = jac(j,:) * aion_inv(j)
    enddo

    ! Energy generation rate Jacobian elements with respect to species

    call get_ebin(dens, ebin)

    do j = 1, nspec
       call ener_gener_rate(jac(1:nspec,j), ebin, jac(net_ienuc,j))
    enddo

    ! Jacobian elements with respect to temperature

    call ener_gener_rate(jac(1:nspec,net_itemp), ebin, jac(net_ienuc,net_itemp))

    call temperature_jac(state, jac)

  end subroutine actual_jac



  subroutine ener_gener_rate(dydt, ebin, enuc)

    use network

    implicit none

    real(rt)         :: dydt(nspec), ebin(nspec), enuc

    enuc = dydt(ic12) * aion(ic12) * ebin(ic12)

  end subroutine ener_gener_rate

end module actual_rhs_module
