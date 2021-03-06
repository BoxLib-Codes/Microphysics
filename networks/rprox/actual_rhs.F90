module actual_rhs_module

  use burn_type_module
  use rate_type_module

  use amrex_fort_module, only : rt => amrex_real
  implicit none

contains

  subroutine actual_rhs_init()

    use screening_module, only: screening_init

    implicit none

    call set_up_screening_factors()

    call screening_init()

  end subroutine actual_rhs_init


  subroutine actual_rhs(state, ydot)

    use amrex_constants_module
    use network
    use rates_module
    use temperature_integration_module, only: temperature_rhs

    implicit none

    type (burn_t), intent(in)    :: state
    real(rt)        , intent(inout) :: ydot(neqs)

    type (rate_t)    :: rr
    real(rt)         :: dens, t9, y(nspec)

    ydot = ZERO

    dens = state % rho
    T9   = state % T * 1.e-9_rt
    y = state % xn * aion_inv

    ! build the rates; weak rates are the wk* variables
    call make_rates(T9, dens, y(1:nspec), state, rr)

    ! set up the ODEs for the species
    call make_ydots(y(1:nspec), T9, state, rr, ydot, .false.)

    ! Energy release
    call ener_gener_rate(ydot(1:nspec), ydot(net_ienuc))

    ! Temperature ODE
    call temperature_rhs(state, ydot)

  end subroutine actual_rhs



  subroutine make_rates(T9, dens, y, state, rr)

    use amrex_constants_module
    use tfactors_module, only : temp_t
    use tfactors_module, only : calc_tfactors
    use rates_module
    use network
    use screening_module

    implicit none

    ! note: y(:) are the molar fractions here
    real(rt)         :: T9, dens, y(nspec)
    type (burn_t), intent(in) :: state
    type (rate_t), intent(out) :: rr

    ! locally used rates
    real(rt)         :: rate,dratedt,wk18ne,wk19ne
    real(rt)         :: r56pg,dr56pgdt,cutoni,dcutonidt,r57decay,dr56eff,ddr56effdt
    real(rt)         :: t9i32

    ! some numbers from appendix C in WW81; these should probably be
    ! updated with current rates
    real(rt)        , parameter :: Lweak = 1.05e0_rt, & ! this is for NS
                                !  Lweak = 0.107e0_rt, & ! this is for lower
                                                      ! densities
                                   la2 = ONE/FIFTEEN ! mean rate from 30s to 56ni
                                                     ! from p-capture and beta
                                                     ! decays

    real(rt) :: sc1a, sc1adt, sc1add
    real(rt) :: sc2a, sc2adt, sc2add
    real(rt) :: sc3a, sc3adt
    integer :: jscr 
    type (plasma_state) :: pstate
    type (temp_t) :: tfactors

    rr % rates(:,:) = ZERO ! Zero out rates

    call calc_tfactors(T9, tfactors)

    ! some common parameters
    rr % rates(1,irLweak) = Lweak
    rr % rates(1,irla2)   = la2

    ! weak rates first
    !
    ! 14o(beta nu)14n
    call rate_o14_to_n14(tfactors,rate,dratedt)
    rr % rates(1,irwk14o) = rate

    ! 15o(beta nu)15n
    call rate_o15_to_n15(tfactors,rate,dratedt)
    rr % rates(1,irwk15o) = rate

    ! 17f(beta nu)17o
    call rate_f17_to_o17(tfactors,rate,dratedt)
    rr % rates(1,irwk17f) = rate

    ! these weak rates aren't needed outside of this routine
    ! 18ne(beta nu)18f
    call rate_ne18_to_f18(tfactors,wk18ne,dratedt)
    ! 19ne(beta nu)19f
    call rate_ne19_to_f19(tfactors,wk19ne,dratedt)


    ! now the remaining rates -- we'll do screening inline here

    call fill_plasma_state(pstate, T9 * 1.e9_rt, dens, y)

    ! 12c(p,g)13n
    call rate_p_c12_to_n13(tfactors,rate,dratedt)
    jscr = 1
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irpg12c) = dens*rate * sc1a
    rr % rates(2,irpg12c) = dens*(dratedt * sc1a + rate * sc1adt)

    ! triple alpha
    call rate_he4_he4_he4_to_c12(tfactors,rate,dratedt)
    jscr = 2
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)
    jscr = 3
    call screen5(pstate, jscr, sc2a, sc2adt, sc2add)
    sc3a = sc1a * sc2a
    sc3adt = sc1adt*sc2a + sc1a*sc2adt

    rr % rates(1,ir3a) = dens*dens*rate * sc3a
    rr % rates(2,ir3a) = dens*dens*(dratedt * sc3a + rate * sc3adt)

    ! 17f(p,g)18ne
    call rate_p_f17_to_ne18(tfactors,rate,dratedt)
    jscr = 4
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irpg17f) = dens*rate * sc1a
    rr % rates(2,irpg17f) = dens*(dratedt * sc1a + rate * sc1adt)

    ! 17f(g,p)16o
    call rate_f17_to_p_o16(tfactors,rate,dratedt)
    ! no screening for gamma-capture
    rr % rates(1,irgp17f) = rate
    rr % rates(2,irgp17f) = dratedt

    ! 15o(a,g)19ne
    call rate_he4_o15_to_ne19(tfactors,rate,dratedt)
    jscr = 5
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irag15o) = dens*rate * sc1a
    rr % rates(2,irag15o) = dens*(dratedt * sc1a + rate * sc1adt)

    ! 16o(a,g)20ne
    call rate_he4_o16_to_ne20(tfactors,rate,dratedt)
    jscr = 6
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irag16o) = dens*rate * sc1a
    rr % rates(2,irag16o) = dens*(dratedt * sc1a + rate * sc1adt)

    ! 16o(p,g)17f
    call rate_p_o16_to_f17(tfactors,rate,dratedt)
    jscr = 7
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irpg16o) = dens*rate * sc1a
    rr % rates(2,irpg16o) = dens*(dratedt * sc1a + rate * sc1adt)

    ! 14o(a,p)17f
    call rate_he4_o14_to_p_f17(tfactors,rate,dratedt)
    jscr = 8
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irap14o) = dens*rate * sc1a
    rr % rates(2,irap14o) = dens*(dratedt * sc1a + rate * sc1adt)

    ! limit CNO as minimum between 14n(p,g)15o and 15o(beta nu)15n
    ! we store the limited rate in irlambCNO; this is lambda_CNO in WW81
    call rate_p_n14_to_o15(tfactors,rate,dratedt)
    jscr = 9
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irlambCNO) = min(rr % rates(1,irwk15o),rate*dens*sc1a*y(ih1))
    if (rr % rates(1,irlambCNO) < rr % rates(1,irwk15o)) then
       rr % rates(2,irlambCNO) = dens*y(ih1)*(dratedt * sc1a + rate * sc1adt)
       rr % rates(3,dlambCNOdh1) = rate*dens * sc1a
    endif

    ! 22mg(...)30s
    ! check if this proceeds via p-captures or (a,p) reactions
    ! the Lweak is from WW81, eqn C15
    ! we store the rate in irlambda1; this is the lambda1 in WW81
    call rate_he4_si26_to_p_p29(tfactors,rate,dratedt)
    jscr = 10
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irlambda1) = max(rr % rates(1,irLweak),dens*y(ihe4)*rate * sc1a)
    if (rr % rates(1,irlambda1) > rr % rates(1,irLweak)) then
       rr  % rates(2,irlambda1) = dens*y(ihe4)*(dratedt * sc1a + rate * sc1adt)
       rr % rates(3,dlambda1dhe4) = dens*rate * sc1a
       ! use the sign of state % rates(1,irlambda1) to indicate the value of delta1 in WW81
       ! if delta1 = 1, then we multiply the rate by -1
       rr % rates(1,irlambda1) = -ONE * rr % rates(1,irlambda1)
    endif

    ! 30s(...) 56ni
    ! check if this proceeds via p-captures or (a,p) reactions
    ! use 44ti(a,p)v47 as a typical limiting rate for the (a,p) process
    ! store this in irlambda2; this is lambda2 in WW81
    call rate_he4_ti44_to_p_v47(tfactors,rate,dratedt)
    jscr = 11
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irlambda2) = max(rr % rates(1,irla2),dens*y(ihe4)*rate * sc1a)
    if (rr % rates(1,irlambda2) > rr % rates(1,irla2)) then
       rr % rates(2,irlambda2) = dens*y(ihe4)*(dratedt * sc1a + rate * sc1adt)
       rr % rates(3,dlambda2dhe4) = dens*rate * sc1a
       ! use the sign of rr % rates(1,irlambda2) to indicate th value of delta2
       ! if delta2 = 1, then we multiply the rate by -1
       rr % rates(1,irlambda2) = -ONE*rr % rates(1,irlambda2)
    endif

    ! form s1 from WW81; branching ratio for 18ne beta decay (wk18ne) vs (a,p)
    ! store result in irs1
    ! 18ne(a,p)21na
    call rate_he4_ne18_to_p_na21(tfactors,rate,dratedt)
    jscr = 12
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irs1) = wk18ne / (wk18ne + dens*y(ihe4)*rate * sc1a)
    rr % rates(2,irs1) = -rr % rates(1,irs1)*dens*y(ihe4)*(dratedt * sc1a + rate * sc1adt) & 
         / (wk18ne + dens*y(ihe4)*rate * sc1a)
    rr % rates(3,drs1dhe4) = -rr % rates(1,irs1)*dens*rate * sc1a &
         / (wk18ne + dens*y(ihe4)*rate * sc1a)

    ! form r1 from WW81; ranching ratio for 19ne beta decay (wk19ne) vs (p,g)
    ! store result in irr1
    ! 19ne(p,g)20na
    call rate_p_ne19_to_na20(tfactors,rate,dratedt)
    jscr = 13
    call screen5(pstate, jscr, sc1a, sc1adt, sc1add)

    rr % rates(1,irr1) = wk19ne / (wk19ne + dens*y(ih1)*rate * sc1a)
    rr % rates(2,irr1) = -rr % rates(1,irr1)*dens*y(ih1)*(dratedt * sc1a + rate * sc1adt) &
         / (wk19ne + dens*y(ih1)*rate * sc1a)
    rr % rates(3,drr1dh1) = -rr % rates(1,irr1)*dens*rate * sc1a &
         / (wk19ne + dens*y(ih1)*rate * sc1a)


    !....
    !....  additional coding for proton capture on 56ni to heavier elements
    !....   kludge    56ni+56p -> 2 (56ni) at a rate given by min
    !....   of 56ni(pg) and 57cu decay rate
    !....
    !....  use 56ni rate from wallace and woosley 1981
    t9i32=tfactors%t9i*sqrt(tfactors%t9i)
    r56pg=dens*(1.29e-02_rt*exp(-4.897_rt*tfactors%t9i) &
         +7.065e+03_rt*exp(-20.33_rt*tfactors%t9i))*t9i32
    dr56pgdt = -THREE*HALF*r56pg*tfactors%t9i + &
         dens*t9i32*tfactors%t9i*tfactors%t9i* &
         (4.897_rt*1.29e-2_rt*exp(-4.897_rt*tfactors%t9i) &
         +20.33_rt*7.065e3_rt*exp(-20.33_rt*tfactors%t9i))
    !....  use generic proton separation energy of 400 kev
    !....  8.02 -> 4.64
    !      cutoni=2.08e-10_rt*dens*exp(8.02*t9m1)/t932
    cutoni=2.08e-10_rt*dens*exp(4.642_rt*tfactors%t9i)*t9i32
    dcutonidt = cutoni*tfactors%t9i*(-THREE*HALF - 4.642_rt*tfactors%t9i)
    r57decay=3.54_rt
    dr56eff=min(r56pg,cutoni*r57decay)
    !   rr % rates(3,r56eff) = d56eff
    !   if (d56eff < r56pg) rr % rates(3,dr56effdt) = r57decay*dcutonidt
    rr % rates(3,r56eff) = ZERO
    rr % rates(3,dr56effdt) = ZERO

  end subroutine make_rates



  subroutine make_ydots(ymol, T9, state, rr, dydt, doing_dratesdt)

    use amrex_constants_module
    use network

    implicit none

    real(rt)        , intent(IN   ) :: ymol(nspec), T9
    logical ,         intent(IN   ) :: doing_dratesdt
    type(burn_t),     intent(IN) :: state
    type(rate_t),     intent(inout) :: rr
    real(rt)        , intent(  OUT) :: dydt(nspec)

    integer          :: rate_idx
    real(rt)         :: ddelta1, ddelta2
    real(rt)         :: dens

    ! initialize
    dydt = ZERO
    dens = state % rho

    ! check to see if we are doing this with the t-derivatives
    ! if so, offset our starting index in the rate groups

    if (doing_dratesdt) then
       rate_idx = 2
    else
       rate_idx = 1
    endif

    if (.not. doing_dratesdt) then
       ddelta1 = ZERO
       ddelta2 = ZERO
       ! figure out the delta's; we used negative rates to indicate delta=1
       if (rr % rates(1,irlambda1) < ZERO) then
          ddelta1 = ONE
          rr % rates(1,irlambda1) = -ONE*rr % rates(1,irlambda1)
       endif
       if (rr % rates(1,irlambda2) < ZERO) then
          ddelta2 = ONE
          rr % rates(1,irlambda2) = -ONE*rr % rates(1,irlambda2)
       endif
       rr % rates(3,delta1) = ddelta1
       rr % rates(3,delta2) = ddelta2
    endif

    ! setup ODEs
    !
    !....
    !.... 12c = 1
    !....
    dydt(ic12)=-ymol(ic12)*ymol(ih1)*rr % rates(rate_idx,irpg12c) &
         +ymol(ihe4)**3*rr % rates(rate_idx,ir3a)/SIX &
         +ymol(io15)*rr % rates(rate_idx,irlambCNO)
    !....
    !.... 14o = 2
    !....
    dydt(io14)=-ymol(io14)*ymol(ihe4)*rr % rates(rate_idx,irap14o) &
         -ymol(io14)*rr % rates(rate_idx,irwk14o) &
         +ymol(ic12)*ymol(ih1)*rr % rates(rate_idx,irpg12c)
    !....
    !.... 15o = 3
    !....
    dydt(io15)=ymol(io14)*rr % rates(rate_idx,irwk14o) &
         -ymol(io15)*ymol(ihe4)*rr % rates(rate_idx,irag15o) &
         -ymol(io15)*rr % rates(rate_idx,irlambCNO) &
         +ymol(if17)*ymol(ih1)*rr % rates(rate_idx,irpg17f)*rr % rates(rate_idx,irs1) &
         +ymol(if17)*rr % rates(rate_idx,irwk17f)
    !....
    !.... 16o = 4
    !....
    dydt(io16) = ymol(if17)*rr % rates(rate_idx,irgp17f) &
         -ymol(io16)*ymol(ih1)*rr % rates(rate_idx,irpg16o) &
         +ymol(io15)*ymol(ihe4)*rr % rates(rate_idx,irr1)*rr % rates(rate_idx,irag15o) &
         -ymol(io16)*ymol(ihe4)*rr % rates(rate_idx,irag16o)
    !....
    !.... 17f = 5
    !....
    dydt(if17)=ymol(io14)*ymol(ihe4)*rr % rates(rate_idx,irap14o) &
         +ymol(io16)*ymol(ih1)*rr % rates(rate_idx,irpg16o) &
         -ymol(if17)*rr % rates(rate_idx,irgp17f) &
         -ymol(if17)*ymol(ih1)*rr % rates(rate_idx,irpg17f) &
         -ymol(if17)*rr % rates(rate_idx,irwk17f)
    !....
    !.... 22mg = 6
    !....
    dydt(img22)=ymol(io16)*ymol(ihe4)*rr % rates(rate_idx,irag16o) &
         +ymol(if17)*ymol(ih1)*rr % rates(rate_idx,irpg17f)*(ONE-rr % rates(rate_idx,irs1)) &
         +ymol(io15)*ymol(ihe4)*rr % rates(rate_idx,irag15o)*(ONE-rr % rates(rate_idx,irr1)) &
         -ymol(img22)*rr % rates(rate_idx,irlambda1)
    !....
    !.... 30s = 7
    !....
    dydt(is30)=ymol(img22)*rr % rates(rate_idx,irlambda1) &
         -ymol(is30)*rr % rates(rate_idx,irlambda2)
    !....
    !.... amax (56ni) = 8  (note that WW81 have a typo -- they write lambda1 here)
    !....
    dydt(ini56)=ymol(is30)*rr % rates(rate_idx,irlambda2)
    !....
    !.... 4he (alpha) = 9
    !....
    dydt(ihe4)=-ymol(ihe4)**3*HALF*rr % rates(rate_idx,ir3a) &
         +ymol(io15)*rr % rates(rate_idx,irlambCNO) &
         -ymol(io14)*ymol(ihe4)*rr % rates(rate_idx,irap14o) &
         +ymol(if17)*ymol(ih1)*rr % rates(rate_idx,irpg17f)*rr % rates(rate_idx,irs1) &
         -ymol(io15)*ymol(ihe4)*rr % rates(rate_idx,irag15o)*(ONE-rr % rates(rate_idx,irr1)) &
         -ymol(io16)*ymol(ihe4)*rr % rates(rate_idx,irag16o) &
         -ymol(if17)*ymol(ih1)*rr % rates(rate_idx,irpg17f)*(ONE-rr % rates(rate_idx,irs1)) &
         +ymol(if17)*rr % rates(rate_idx,irwk17f) &
         -TWO*ymol(img22)*rr % rates(rate_idx,irlambda1)*rr % rates(3,delta1) &
         -6.5e0_rt*ymol(is30)*rr % rates(rate_idx,irlambda2)*rr % rates(3,delta2)
    !....
    !.... 1h (p) = 10
    !....
    dydt(ih1)=-ymol(io14)*rr % rates(rate_idx,irwk14o) &
         -ymol(io15)*rr % rates(rate_idx,irlambCNO) &
         -TWO*ymol(ic12)*ymol(ih1)*rr % rates(rate_idx,irpg12c) &
         +ymol(io14)*ymol(ihe4)*rr % rates(rate_idx,irap14o) &
         -TWO*ymol(if17)*ymol(ih1)*rr % rates(rate_idx,irpg17f)*rr % rates(rate_idx,irs1) &
         +ymol(if17)*rr % rates(rate_idx,irgp17f) &
         -ymol(io16)*ymol(ih1)*rr % rates(rate_idx,irpg16o) &
         -ymol(io15)*ymol(ihe4)*rr % rates(rate_idx,irag15o)*rr % rates(rate_idx,irr1) &
         -TWO*ymol(io16)*ymol(ihe4)*rr % rates(rate_idx,irag16o) &
         -THREE*ymol(io15)*ymol(ihe4)*rr % rates(rate_idx,irag15o)*(ONE-rr % rates(rate_idx,irr1)) &
         -ymol(if17)*ymol(ih1)*rr % rates(rate_idx,irpg17f)*(ONE-rr % rates(rate_idx,irs1)) &
         -TWO*ymol(if17)*rr % rates(rate_idx,irwk17f) &
         -EIGHT*ymol(img22)*rr % rates(rate_idx,irlambda1)*(ONE-rr % rates(3,delta1)) &
         -26.e0_rt*ymol(is30)*rr % rates(rate_idx,irlambda2)*(ONE-rr % rates(3,delta2))


    if (.not. doing_dratesdt) then
       dydt(ini56) = dydt(ini56)+ymol(ini56)*ymol(ih1)*rr % rates(3,r56eff)
       dydt(ih1) = dydt(ih1)-56.0e0_rt*ymol(ini56)*ymol(ih1)*rr % rates(3,r56eff)
    else
       dydt(ini56) = dydt(ini56)+ymol(ini56)*ymol(ih1)*rr % rates(3,dr56effdt)
       dydt(ih1) = dydt(ih1)-56.0e0_rt*ymol(ini56)*ymol(ih1)*rr % rates(3,dr56effdt)
    endif

  end subroutine make_ydots




  subroutine actual_jac(state, jac)

    use amrex_constants_module
    use network
    use temperature_integration_module, only: temperature_jac

    implicit none

    type (burn_t), intent(in)    :: state
    real(rt)        , intent(inout) :: jac(njrows, njcols)

    type (rate_t) :: rr
    real(rt)         :: dens, ymol(nspec), T9, ydot(nspec)
    real(rt)         :: psum
    integer          :: i, j

    ! initialize
    jac(:,:) = ZERO
    ymol = state % xn * aion_inv
    T9 = state % T * 1.e-9_rt

    dens = state % rho

    ! build the rates; weak rates are the wk* variables
    call make_rates(T9, dens, ymol(1:nspec), state, rr)


    ! carbon-12
    jac(ic12,ic12) = -ymol(ih1)*rr % rates(1,irpg12c)
    jac(ic12,io15) = rr % rates(1,irlambCNO)
    jac(ic12,ihe4) = HALF*ymol(ihe4)*ymol(ihe4)*rr % rates(1,ir3a)
    jac(ic12,ih1)  = -ymol(ic12)*rr % rates(1,irpg12c) &
         +ymol(io15)*rr % rates(3,dlambCNOdh1)

    ! oxygen-14
    jac(io14,ic12) = ymol(ih1)*rr % rates(1,irpg12c)
    jac(io14,io14) = -ymol(ihe4)*rr % rates(1,irap14o) &
         -rr % rates(1,irwk14o)
    jac(io14,ihe4) = -ymol(io14)*rr % rates(1,irap14o)
    jac(io14,ih1)  = ymol(ic12)*rr % rates(1,irpg12c)

    ! oxygen-15
    jac(io15,io14) = rr % rates(1,irwk14o)
    jac(io15,io15) = -ymol(ihe4)*rr % rates(1,irag15o) &
         -rr % rates(1,irlambCNO)
    jac(io15,if17) = ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(1,irs1) &
         +rr % rates(1,irwk17f)
    jac(io15,ihe4) = -ymol(io15)*rr % rates(1,irag15o) &
         +ymol(if17)*ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(3,drs1dhe4)
    jac(io15,ih1)  = ymol(if17)*rr % rates(1,irpg17f)*rr % rates(1,irs1) &
         -ymol(io15)*rr % rates(3,dlambCNOdh1)

    ! oxygen-16
    jac(io16,io15) = ymol(ihe4)*rr % rates(1,irr1)*rr % rates(1,irag15o)
    jac(io16,io16) = -ymol(ih1)*rr % rates(1,irpg16o) &
         -ymol(ihe4)*rr % rates(1,irag16o)
    jac(io16,if17) = rr % rates(1,irgp17f)
    jac(io16,ihe4) = ymol(io15)*rr % rates(1,irr1)*rr % rates(1,irag15o) &
         -ymol(io16)*rr % rates(1,irag16o)
    jac(io16,ih1)  = -ymol(io16)*rr % rates(1,irpg16o) &
         +ymol(io15)*ymol(ihe4)*rr % rates(3,drr1dh1)*rr % rates(1,irag15o)

    ! flourine-17
    jac(if17,io14) = ymol(ihe4)*rr % rates(1,irap14o)
    jac(if17,io16) = ymol(ih1)*rr % rates(1,irpg16o)
    jac(if17,if17) = -rr % rates(1,irgp17f) &
         -ymol(ih1)*rr % rates(1,irpg17f) &
         -rr % rates(1,irwk17f)
    jac(if17,ihe4) = ymol(io14)*rr % rates(1,irap14o)
    jac(if17,ih1)  = ymol(io16)*rr % rates(1,irpg16o) &
         -ymol(if17)*rr % rates(1,irpg17f)

    ! magnesium-22
    jac(img22,io15) = ymol(ihe4)*rr % rates(1,irag15o)*(ONE-rr % rates(1,irr1))
    jac(img22,io16) = ymol(ihe4)*rr % rates(1,irag16o)
    jac(img22,if17) = ymol(ih1)*rr % rates(1,irpg17f)*(ONE-rr % rates(1,irs1))
    jac(img22,img22) = -rr % rates(1,irlambda1)
    jac(img22,ihe4) = ymol(io16)*rr % rates(1,irag16o) &
         +ymol(io15)*rr % rates(1,irag15o)*(ONE-rr % rates(1,irr1)) &
         -ymol(if17)*ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(3,drs1dhe4) &
         -ymol(img22)*rr % rates(3,dlambda1dhe4)
    jac(img22,ih1)  = ymol(if17)*rr % rates(1,irpg17f)*(ONE-rr % rates(1,irs1)) &
         -ymol(io15)*ymol(ihe4)*rr % rates(1,irag15o)*rr % rates(3,drr1dh1)

    ! sulfur-30
    jac(is30,img22) = rr % rates(1,irlambda1)
    jac(is30,is30)  = -rr % rates(1,irlambda2)
    jac(is30,ihe4)  = ymol(img22)*rr % rates(3,dlambda1dhe4) &
         -ymol(is30)*rr % rates(3,dlambda2dhe4)

    ! nickel-56
    jac(ini56,is30) = rr % rates(1,irlambda2)
    jac(ini56,ini56) = ymol(ih1)*rr % rates(3,r56eff)
    jac(ini56,ihe4) = ymol(is30)*rr % rates(3,dlambda2dhe4)
    jac(ini56,ih1) = ymol(ini56)*rr % rates(3,r56eff)

    ! helium-4
    jac(ihe4,io14) = -ymol(ihe4)*rr % rates(1,irap14o)
    jac(ihe4,io15) = rr % rates(1,irlambCNO) &
         -ymol(ihe4)*rr % rates(1,irag15o)*(ONE-rr % rates(1,irr1))
    jac(ihe4,io16) = -ymol(ihe4)*rr % rates(1,irag16o)
    jac(ihe4,if17) = ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(1,irs1) &
         -ymol(ih1)*rr % rates(1,irpg17f)*(ONE-rr % rates(1,irs1)) &
         +rr % rates(1,irwk17f)
    jac(ihe4,img22) = -TWO*rr % rates(1,irlambda1)*rr % rates(3,delta1)
    jac(ihe4,is30) = -6.5e0_rt*rr % rates(1,irlambda2)*rr % rates(3,delta2)
    jac(ihe4,ihe4) = -THREE*ymol(ihe4)*ymol(ihe4)*HALF*rr % rates(1,ir3a) &
         -ymol(io14)*rr % rates(1,irap14o) &
         -ymol(io16)*rr % rates(1,irag16o) &
         -ymol(io15)*rr % rates(1,irag15o)*(ONE-rr % rates(1,irr1)) &
         +ymol(if17)*ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(3,drs1dhe4) &
         +ymol(if17)*ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(3,drs1dhe4) &
         -TWO*ymol(img22)*rr % rates(3,dlambda1dhe4)*rr % rates(3,delta1) &
         -6.5e0_rt*ymol(is30)*rr % rates(3,dlambda2dhe4)*rr % rates(3,delta2)
    jac(ihe4,ih1)  = ymol(if17)*rr % rates(1,irpg17f)*rr % rates(1,irs1) &
         -ymol(if17)*rr % rates(1,irpg17f)*(ONE-rr % rates(1,irs1)) &
         +ymol(io15)*rr % rates(3,dlambCNOdh1) &
         +ymol(io15)*ymol(ihe4)*rr % rates(1,irag15o)*rr % rates(3,drr1dh1)

    ! hydrogen-1
    jac(ih1,ic12) = -TWO*ymol(ih1)*rr % rates(1,irpg12c)
    jac(ih1,io14) = ymol(ihe4)*rr % rates(1,irap14o) &
         -rr % rates(1,irwk14o)
    jac(ih1,io15) = -rr % rates(1,irlambCNO) &
         -ymol(ihe4)*rr % rates(1,irag15o)*rr % rates(1,irr1) &
         -THREE*ymol(ihe4)*rr % rates(1,irag15o)*(ONE-rr % rates(1,irr1))
    jac(ih1,io16) = -ymol(ih1)*rr % rates(1,irpg16o) &
         -TWO*ymol(ihe4)*rr % rates(1,irag16o)
    jac(ih1,if17) = -TWO*ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(1,irs1) &
         +rr % rates(1,irgp17f) &
         -ymol(ih1)*rr % rates(1,irpg17f)*(ONE-rr % rates(1,irs1)) &
         -TWO*rr % rates(1,irwk17f)
    jac(ih1,img22) = -EIGHT*rr % rates(1,irlambda1)*(ONE-rr % rates(3,delta1))
    jac(ih1,is30)  = -26.e0_rt*rr % rates(1,irlambda2)*(ONE-rr % rates(3,delta2))
    jac(ih1,ini56) = -56.0e0_rt*ymol(ih1)*rr % rates(3,r56eff)
    jac(ih1,ihe4) = ymol(io14)*rr % rates(1,irap14o) &
         -ymol(io15)*rr % rates(1,irag15o)*rr % rates(1,irr1) &
         -TWO*ymol(io16)*rr % rates(1,irag16o) &
         -THREE*ymol(io15)*rr % rates(1,irag15o)*(ONE-rr % rates(1,irr1)) &
         -ymol(if17)*ymol(ih1)*rr % rates(1,irpg17f)*rr % rates(3,drs1dhe4) &
         -EIGHT*ymol(img22)*rr % rates(3,dlambda1dhe4)*(ONE-rr % rates(3,delta1)) &
         -26.e0_rt*ymol(is30)*rr % rates(3,dlambda2dhe4)*(ONE-rr % rates(3,delta2))
    jac(ih1,ih1)  = -TWO*ymol(ic12)*rr % rates(1,irpg12c) &
         -TWO*ymol(if17)*rr % rates(1,irpg17f)*rr % rates(1,irs1) &
         -ymol(io16)*rr % rates(1,irpg16o) &
         -ymol(if17)*rr % rates(1,irpg17f)*(ONE-rr % rates(1,irs1)) &
         -ymol(io15)*rr % rates(3,dlambCNOdh1) &
         +TWO*ymol(io15)*ymol(ihe4)*rr % rates(1,irag15o)*rr % rates(3,drr1dh1) &
         -56.0e0_rt*ymol(ini56)*rr % rates(3,r56eff)

    ! temperature derivatives df(Y)/df(T)
    call make_ydots(ymol, T9, state, rr, ydot, .true.)

    jac(1:nspec, net_itemp) = ydot

    ! Energy generation rate Jacobian elements with respect to species

    do j = 1, nspec
       call ener_gener_rate(jac(1:nspec,j), jac(net_ienuc,j))
    enddo

    ! Jacobian elements with respect to temperature

    call ener_gener_rate(jac(1:nspec,net_itemp), jac(net_ienuc,net_itemp))

    ! Temperature Jacobian elements

    call temperature_jac(state, jac)

  end subroutine actual_jac



  subroutine ener_gener_rate(dydt, enuc)

    use network

    implicit none

    real(rt)         :: dydt(nspec), enuc

    enuc = -sum(dydt(:) * aion(1:nspec) * ebin(1:nspec))

  end subroutine ener_gener_rate

  ! Compute and store the more expensive screening factors

  subroutine set_up_screening_factors()

    use screening_module, only: add_screening_factor
    use network

    implicit none

    ! note: it is critical that these are called in the exact order
    ! that the screening calls are done in the RHS routine, since we
    ! use that order in the screening

    ! 1: C12(p,g)N13
    call add_screening_factor(zion(ic12),aion(ic12),zion(ih1),aion(ih1))

    ! 2, 3: 3-alpha
    call add_screening_factor(zion(ihe4),aion(ihe4),zion(ihe4),aion(ihe4))
    call add_screening_factor(zion(ihe4),aion(ihe4),4.0e0_rt,8.0e0_rt)

    ! 4: F17(p,g)Ne18
    call add_screening_factor(zion(if17),aion(if17),zion(ih1),aion(ih1))

    ! F17(g,p)O16 is unscreened

    ! 5: O15(a,g)Ne19
    call add_screening_factor(zion(io15),aion(io15),zion(ihe4),aion(ihe4))

    ! 6: O16(a,g)Ne20
    call add_screening_factor(zion(io16),aion(io16),zion(ihe4),aion(ihe4))

    ! 7: O16(p,g)F17
    call add_screening_factor(zion(io16),aion(io16),zion(ih1),aion(ih1))

    ! 8: O14(a,p)F17
    call add_screening_factor(zion(io14),aion(io14),zion(ihe4),aion(ihe4))

    ! 9: N14(p,g)O15
    call add_screening_factor(7.0_rt,14.0_rt,zion(ih1),aion(ih1))

    ! 10: Si26(a,p)P29
    call add_screening_factor(14.0_rt,26.0_rt,zion(ihe4),aion(ihe4))

    ! 11: Ti44(a,p)V47
    call add_screening_factor(22.0_rt,44.0_rt,zion(ihe4),aion(ihe4))

    ! 12: Ne18(a,p)Na21
    call add_screening_factor(10.0e0_rt,18.0e0_rt,zion(ihe4),aion(ihe4))

    ! 13: Ne19(p,g)Na20
    call add_screening_factor(10.0e0_rt,19.0e0_rt,zion(ih1),aion(ih1))

  end subroutine set_up_screening_factors


end module actual_rhs_module
