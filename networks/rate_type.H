#ifndef _rate_type_H_
#define _rate_type_H_

#include <AMReX_REAL.H>
#include <AMReX_Array.H>

#include <actual_network.H>

struct rate_t
{
    // the rate data
    amrex::Array1D<amrex::Real, 1, Rates::NumRates> rates;
};

struct rate_fr_t
{
    // the forward and reverse rate data
    amrex::Array1D<amrex::Real, 1, Rates::NumRates / 2> forward_rates;
    amrex::Array1D<amrex::Real, 1, Rates::NumRates / 2> reverse_rates;
};

#endif
