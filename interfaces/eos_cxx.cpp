#include <eos.H>
#include <eos_F.H>
#include <eos_composition.H>
#include <actual_eos.H>
#include <AMReX_Algorithm.H>

namespace EOSData
{
  bool initialized;
  AMREX_GPU_MANAGED Real mintemp;
  AMREX_GPU_MANAGED Real maxtemp;
  AMREX_GPU_MANAGED Real mindens;
  AMREX_GPU_MANAGED Real maxdens;
  AMREX_GPU_MANAGED Real minx;
  AMREX_GPU_MANAGED Real maxx;
  AMREX_GPU_MANAGED Real minye;
  AMREX_GPU_MANAGED Real maxye;
  AMREX_GPU_MANAGED Real mine;
  AMREX_GPU_MANAGED Real maxe;
  AMREX_GPU_MANAGED Real minp;
  AMREX_GPU_MANAGED Real maxp;
  AMREX_GPU_MANAGED Real mins;
  AMREX_GPU_MANAGED Real maxs;
  AMREX_GPU_MANAGED Real minh;
  AMREX_GPU_MANAGED Real maxh;
}



// EOS initialization routine: read in general EOS parameters, then
// call any specific initialization used by the EOS.

void eos_cxx_init() {

  // Allocate and set default values

  EOSData::mintemp = 1.e-200;
  EOSData::maxtemp = 1.e200;
  EOSData::mindens = 1.e-200;
  EOSData::maxdens = 1.e200;
  EOSData::minx = 1.e-200;
  EOSData::maxx = 1.0 + 1.e-12;
  EOSData::minye = 1.e-200;
  EOSData::maxye = 1.0 + 1.e-12;
  EOSData::mine = 1.e-200;
  EOSData::maxe = 1.e200;
  EOSData::minp = 1.e-200;
  EOSData::maxp = 1.e200;
  EOSData::mins = 1.e-200;
  EOSData::maxs = 1.e200;
  EOSData::minh = 1.e-200;
  EOSData::maxh = 1.e200;

  // Set up any specific parameters or initialization steps required by the EOS we are using.
  actual_eos_cxx_init();

  // we take the approach that the Fortran initialization is the
  // reference and it has already been done, so we get any overrides
  // to these from Fortran, to ensure we are consistent.


  // If they exist, save the minimum permitted user temperature and density.
  // These are only relevant to this module if they are larger than the minimum
  // possible EOS quantities. We will reset them to be equal to the EOS minimum
  // if they are smaller than that.

  Real scratch;
  eos_get_small_temp(&scratch);
  EOSData::mintemp = scratch;

  eos_get_small_dens(&scratch);
  EOSData::mindens = scratch;

  EOSData::initialized = true;

}


void eos_cxx_finalize() {

  actual_eos_cxx_finalize();

}


AMREX_GPU_HOST_DEVICE
void eos_cxx(const eos_input_t input, eos_t& state, bool use_raw_inputs) {

  // Input arguments

  bool has_been_reset = false;
  bool use_composition_routine = true;


  // Local variables

#ifndef AMREX_USE_GPU
  if (!EOSData::initialized) {
    amrex::Error("EOS: not initialized");
  }
#endif

  if (use_raw_inputs) {
    use_composition_routine = false;
  }

  if (use_composition_routine) {
    // Get abar, zbar, etc.
    composition(state);
  }

  // Force the inputs to be valid.
  reset_inputs(input, state, has_been_reset);

  // Allow the user to override any details of the
  // EOS state. This should generally occur right
  // before the actual_eos call.

  //call eos_override(state)

  // Call the EOS.

  if (!has_been_reset) {
    actual_eos_cxx(input, state);
  }
}

AMREX_GPU_HOST_DEVICE
void reset_inputs(const eos_input_t input, eos_t& state, bool& has_been_reset) {

  // Reset the input quantities to valid values. For inputs other than rho and T,
  // this will evolve an EOS call, which will negate the need to do the main EOS call.

  switch (input) {

  case eos_input_rt:

    reset_rho(state, has_been_reset);
    reset_T(state, has_been_reset);

    break;

  case eos_input_rh:

    reset_rho(state, has_been_reset);
    reset_h(state, has_been_reset);

    break;

  case eos_input_tp:

    reset_T(state, has_been_reset);
    reset_p(state, has_been_reset);

    break;

  case eos_input_rp:

    reset_rho(state, has_been_reset);
    reset_p(state, has_been_reset);

    break;

  case eos_input_re:

    reset_rho(state, has_been_reset);
    reset_e(state, has_been_reset);

    break;

  case eos_input_ps:

    reset_p(state, has_been_reset);
    reset_s(state, has_been_reset);

    break;

  case eos_input_ph:

    reset_p(state, has_been_reset);
    reset_h(state, has_been_reset);

    break;

  case eos_input_th:

    reset_T(state, has_been_reset);
    reset_h(state, has_been_reset);

    break;
  }

}



// For density, just ensure that it is within mindens and maxdens.
inline void reset_rho(eos_t& state, bool& has_been_reset) {

  state.rho = amrex::min(EOSData::maxdens, amrex::max(EOSData::mindens, state.rho));
}

// For temperature, just ensure that it is within mintemp and maxtemp.
inline void reset_T(eos_t& state, bool& has_been_reset) {

  state.T = amrex::min(EOSData::maxtemp, amrex::max(EOSData::mintemp, state.T));
}


void reset_e(eos_t& state, bool& has_been_reset) {

  if (state.e < EOSData::mine || state.e > EOSData::maxe) {
    eos_reset(state, has_been_reset);
  }
}

void reset_h(eos_t& state, bool& has_been_reset) {

  if (state.h < EOSData::minh || state.h > EOSData::maxh) {
    eos_reset(state, has_been_reset);
  }
}

void reset_s(eos_t& state, bool& has_been_reset) {

  if (state.s < EOSData::mins || state.s > EOSData::maxs) {
    eos_reset(state, has_been_reset);
  }
}

void reset_p(eos_t& state, bool& has_been_reset) {

  if (state.p < EOSData::minp || state.p > EOSData::maxp) {
    eos_reset(state, has_been_reset);
  }
}


// Given an EOS state, ensure that rho and T are
// valid, then call with eos_input_rt.
void eos_reset(eos_t& state, bool& has_been_reset) {

  state.T = amrex::min(EOSData::maxtemp, amrex::max(EOSData::mintemp, state.T));
  state.rho = amrex::min(EOSData::maxdens, amrex::max(EOSData::mindens, state.rho));

  actual_eos_cxx(eos_input_rt, state);

  has_been_reset = true;
}


#ifndef AMREX_USE_GPU
void check_inputs(const eos_input_t input, eos_t& state) {

  // Check the inputs for validity.

  for (int n = 0; n < NumSpec; n++) {
    if (state.xn[n] < EOSData::minx) {
      print_state(state);
      amrex::Error("EOS: mass fraction less than minimum possible mass fraction.");

    } else if (state.xn[n] > EOSData::maxx) {
      print_state(state);
      amrex::Error("EOS: mass fraction more than maximum possible mass fraction.");
    }
  }

  if (state.y_e > EOSData::minye) {
    print_state(state);
    amrex::Error("EOS: y_e less than minimum possible electron fraction.");

  } else if (state.y_e > EOSData::maxye) {
    print_state(state);
    amrex::Error("EOS: y_e greater than maximum possible electron fraction.");
  }

  switch (input) {

  case eos_input_rt:

    check_rho(state);
    check_T(state);
    break;

  case eos_input_rh:

    check_rho(state);
    check_h(state);
    break;

  case eos_input_tp:

    check_T(state);
    check_p(state);
    break;

  case eos_input_rp:

    check_rho(state);
    check_p(state);
    break;

  case eos_input_re:

    check_rho(state);
    check_e(state);
    break;

  case eos_input_ps:

    check_p(state);
    check_s(state);
    break;

  case eos_input_ph:

    check_p(state);
    check_h(state);
    break;

  case eos_input_th:

    check_T(state);
    check_h(state);

  }
}


void check_rho(eos_t& state) {

  if (state.rho < EOSData::mindens) {
    print_state(state);
    amrex::Error("EOS: rho smaller than mindens.");

  } else if (state.rho > EOSData::maxdens) {
    print_state(state);
    amrex::Error("EOS: rho greater than maxdens.");
  }
}

void check_T(eos_t& state) {

  if (state.T < EOSData::mintemp) {
    print_state(state);
    amrex::Error("EOS: T smaller than mintemp.");

  } else if (state.T > EOSData::maxtemp) {
    print_state(state);
    amrex::Error("EOS: T greater than maxtemp.");
  }
}

void check_e(eos_t& state) {

  if (state.e < EOSData::mine) {
    print_state(state);
    amrex::Error("EOS: e smaller than mine.");

  } else if (state.e > EOSData::maxe) {
    print_state(state);
    amrex::Error("EOS: e greater than maxe.");
  }
}

void check_h(eos_t& state) {

  if (state.h < EOSData::minh) {
    print_state(state);
    amrex::Error("EOS: h smaller than minh.");

  } else if (state.h > EOSData::maxh) {
    print_state(state);
    amrex::Error("EOS: h greater than maxh.");

  }
}

void check_s(eos_t& state) {

  if (state.s < EOSData::mins) {
    print_state(state);
    amrex::Error("EOS: s smaller than mins.");

  } else if (state.s > EOSData::maxs) {
    print_state(state);
    amrex::Error("EOS: s greater than maxs.");
  }
}

void check_p(eos_t& state) {

  if (state.p < EOSData::minp) {
    print_state(state);
    amrex::Error("EOS: p smaller than minp.");

  } else if (state.p > EOSData::maxp) {
    print_state(state);
    amrex::Error("EOS: p greater than maxp.");
  }
}
#endif
