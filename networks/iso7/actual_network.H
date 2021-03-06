#ifndef _actual_network_H_
#define _actual_network_H_

#include <AMReX_REAL.H>
#include <AMReX_Vector.H>
#include <AMReX_Array.H>

#include <fundamental_constants.H>
#include <network_properties.H>
#include <network_utilities.H>

using namespace amrex;

void actual_network_init();

const std::string network_name = "iso7";

namespace network
{
    extern AMREX_GPU_MANAGED amrex::Array1D<amrex::Real, 1, NumSpec> bion;
    extern AMREX_GPU_MANAGED amrex::Array1D<amrex::Real, 1, NumSpec> mion;
    extern AMREX_GPU_MANAGED amrex::Array1D<amrex::Real, 1, NumSpec> wion;
}

namespace Rates {
    enum NetworkRatesFR {
        C12_He4_to_O16 = 1,
        He4_He4_He4_to_C12,
        C12_C12_to_Ne20_He4,
        C12_O16_to_Mg24_He4,
        C12_O16_to_Si28,
        O16_O16_to_Si28_He4,
        O16_He4_to_Ne20,
        Ne20_He4_to_Mg24,
        Mg24_He4_to_Si28,
        Ca40_He4_to_Ti44,
        Si28_7He4_to_Ni56,
        NumRatesFR = Si28_7He4_to_Ni56
    };

    enum NetworkRates {C12_He4_to_O16_forward = 1,
                       C12_He4_to_O16_reverse,
                       He4_He4_He4_to_C12_forward,
                       He4_He4_He4_to_C12_reverse,
                       C12_C12_to_Ne20_He4_forward,
                       C12_C12_to_Ne20_He4_reverse,
                       C12_O16_to_Mg24_He4_forward,
                       C12_O16_to_Mg24_He4_reverse,
                       C12_O16_to_Si28_forward,
                       C12_O16_to_Si28_reverse,
                       O16_O16_to_Si28_He4_forward,
                       O16_O16_to_Si28_He4_reverse,
                       O16_He4_to_Ne20_forward,
                       O16_He4_to_Ne20_reverse,
                       Ne20_He4_to_Mg24_forward,
                       Ne20_He4_to_Mg24_reverse,
                       Mg24_He4_to_Si28_forward,
                       Mg24_He4_to_Si28_reverse,
                       Ca40_He4_to_Ti44_forward,
                       Ca40_He4_to_Ti44_reverse,
                       Si28_7He4_to_Ni56_forward,
                       Si28_7He4_to_Ni56_reverse,
                       NumRates = Si28_7He4_to_Ni56_reverse};

    const int NumGroups = 2 + NumSpec;
}

namespace RHS {

    AMREX_GPU_HOST_DEVICE AMREX_INLINE
    constexpr rhs_t rhs_data (int rate)
    {
        using namespace Species;
        using namespace Rates;

        rhs_t data{};

        data.species_A = -1;
        data.species_B = -1;
        data.species_C = -1;
        data.species_D = -1;
        data.species_E = -1;
        data.species_F = -1;

        data.number_A = 0;
        data.number_B = 0;
        data.number_C = 0;
        data.number_D = 0;
        data.number_E = 0;
        data.number_F = 0;

        data.exponent_A = 0;
        data.exponent_B = 0;
        data.exponent_C = 0;
        data.exponent_D = 0;
        data.exponent_E = 0;
        data.exponent_F = 0;

        switch (rate) {

        case He4_He4_He4_to_C12:
            data.species_A = He4;
            data.species_D = C12;

            data.number_A = 3;
            data.number_D = 1;

            data.exponent_A = 3;
            data.exponent_D = 1;
            break;

        case C12_He4_to_O16:
            data.species_A = C12;
            data.species_B = He4;
            data.species_D = O16;

            data.number_A = 1;
            data.number_B = 1;
            data.number_D = 1;

            data.exponent_A = 1;
            data.exponent_B = 1;
            data.exponent_D = 1;
            break;

        case C12_C12_to_Ne20_He4:
            data.species_A = C12;
            data.species_D = Ne20;
            data.species_E = He4;

            data.number_A = 2;
            data.number_D = 1;
            data.number_E = 1;

            data.exponent_A = 2;
            data.exponent_D = 1;
            data.exponent_E = 1;
            break;

        case C12_O16_to_Mg24_He4:
            data.species_A = C12;
            data.species_B = O16;
            data.species_D = Mg24;
            data.species_E = He4;

            data.number_A = 1;
            data.number_B = 1;
            data.number_D = 1;
            data.number_E = 1;

            data.exponent_A = 1;
            data.exponent_B = 1;
            data.exponent_D = 1;
            data.exponent_E = 1;
            break;

        case C12_O16_to_Si28:
            data.species_A = C12;
            data.species_B = O16;
            data.species_D = Si28;

            data.number_A = 1;
            data.number_B = 1;
            data.number_D = 1;

            data.exponent_A = 1;
            data.exponent_B = 1;
            data.exponent_D = 1;
            break;

        case O16_O16_to_Si28_He4:
            data.species_A = O16;
            data.species_D = Si28;
            data.species_E = He4;

            data.number_A = 2;
            data.number_D = 1;
            data.number_E = 1;

            data.exponent_A = 2;
            data.exponent_D = 1;
            data.exponent_E = 1;
            break;

        case O16_He4_to_Ne20:
            data.species_A = O16;
            data.species_B = He4;
            data.species_D = Ne20;

            data.number_A = 1;
            data.number_B = 1;
            data.number_D = 1;

            data.exponent_A = 1;
            data.exponent_B = 1;
            data.exponent_D = 1;
            break;

        case Ne20_He4_to_Mg24:
            data.species_A = Ne20;
            data.species_B = He4;
            data.species_D = Mg24;

            data.number_A = 1;
            data.number_B = 1;
            data.number_D = 1;

            data.exponent_A = 1;
            data.exponent_B = 1;
            data.exponent_D = 1;
            break;

        case Mg24_He4_to_Si28:
            data.species_A = Mg24;
            data.species_B = He4;
            data.species_D = Si28;

            data.number_A = 1;
            data.number_B = 1;
            data.number_D = 1;

            data.exponent_A = 1;
            data.exponent_B = 1;
            data.exponent_D = 1;
            break;

        case Si28_7He4_to_Ni56:
            data.species_A = Si28;
            data.species_B = He4;
            data.species_D = Ni56;

            data.number_A = 1;
            data.number_B = 7;
            data.number_D = 1;

            data.exponent_A = 1;
            data.exponent_B = 1;
            data.exponent_D = 1;
            break;

        }

        return data;
    }

}

#endif
