#!/usr/bin/env python3

"""This routine parses plain-text parameter files that list runtime
parameters for use in our codes.  The general format of a parameter
is:

max_step                            integer            1
small_dt                            real               1.d-10
xlo_boundary_type                   character          ""
octant                              logical            .false.

This specifies the runtime parameter name, datatype, and default
value.

An optional 4th column can be used to indicate the priority -- if,
when parsing the collection of parameter files, a duplicate of an
existing parameter is encountered, the value from the one with
the highest priority (largest integer) is retained.

This script takes a template file and replaces keywords in it
(delimited by @@...@@) with the Fortran code required to
initialize the parameters, setup a namelist, and allow for
commandline overriding of their defaults.

"""

import os
import sys
import argparse
import runtime_parameters

HEADER = """
! DO NOT EDIT THIS FILE!!!
!
! This file is automatically generated by write_probin.py at
! compile-time.
!
! To add a runtime parameter, do so by editting the appropriate _parameters
! file.

"""

CXX_F_HEADER = """
#ifndef _external_parameters_F_H_
#define _external_parameters_F_H_
#include <AMReX.H>
#include <AMReX_BLFort.H>

#ifdef __cplusplus
#include <AMReX.H>
extern "C"
{
#endif

void update_fortran_extern_after_cxx();

"""

CXX_F_FOOTER = """
#ifdef __cplusplus
}
#endif

#endif
"""

CXX_HEADER = """
#ifndef _external_parameters_H_
#define _external_parameters_H_
#include <AMReX_BLFort.H>

"""

CXX_FOOTER = """
#endif
"""


def get_next_line(fin):
    """return the next, non-blank line, with comments stripped"""
    line = fin.readline()

    pos = line.find("#")

    while (pos == 0 or line.strip() == "") and line:
        line = fin.readline()
        pos = line.find("#")

    return line[:pos]


def parse_param_file(params_list, param_file):
    """read all the parameters in a given parameter file and add valid
    parameters to the params list.
    """

    namespace = None

    try:
        f = open(param_file, "r")
    except IOError:
        sys.exit(f"write_probin.py: ERROR: file {param_file} does not exist")
    else:
        print(f"write_probin.py: working on parameter file {param_file}...")

    line = get_next_line(f)

    err = 0

    while line and not err:

        if line[0] == "@":
            # this defines a namespace
            cmd, value = line.split(":")
            if cmd == "@namespace":
                namespace = value
            else:
                sys.exit("invalid command")

            line = get_next_line(f)
            continue

        fields = line.split()

        if len(fields) < 3:
            print("write_probin.py: ERROR: missing one or more fields in parameter definition.")
            err = 1
            continue

        name = fields[0]
        dtype = fields[1]
        default = fields[2]

        current_param = runtime_parameters.Param(name, dtype, default,
                                                 in_fortran=1,
                                                 namespace=namespace,
                                                 skip_namespace_in_declare=True)

        try:
            current_param.priority = int(fields[3])
        except:
            pass

        skip = 0

        # check to see if this parameter is defined in the current list
        # if so, keep the one with the highest priority
        p_names = [p.name for p in params_list]
        try:
            idx = p_names.index(current_param.name)
        except ValueError:
            pass
        else:
            if params_list[idx].namespace == current_param.namespace:
                if params_list[idx] < current_param:
                    params_list.pop(idx)
                else:
                    skip = 1

        if not err == 1 and not skip == 1:
            params_list.append(current_param)

        line = get_next_line(f)

    return err


def abort(outfile):
    """ abort exits when there is an error.  A dummy stub file is written
    out, which will cause a compilation failure """

    fout = open(outfile, "w")
    fout.write("There was an error parsing the parameter files")
    fout.close()
    sys.exit(1)


def write_probin(probin_template, param_files,
                 namelist_name, out_file, cxx_prefix):

    """ write_probin will read through the list of parameter files and
    output the new out_file """

    params = []

    print(" ")
    print(f"write_probin.py: creating {out_file}")

    # read the parameters defined in the parameter files

    for f in param_files:
        err = parse_param_file(params, f)
        if err:
            abort(out_file)

    # open up the template
    try:
        ftemplate = open(probin_template, "r")
    except IOError:
        sys.exit(f"write_probin.py: ERROR: file {probin_template} does not exist")

    template_lines = ftemplate.readlines()

    ftemplate.close()

    # output the template, inserting the parameter info in between the @@...@@
    fout = open(out_file, "w")

    fout.write(HEADER)

    for line in template_lines:

        index = line.find("@@")

        if index >= 0:
            index2 = line.rfind("@@")

            keyword = line[index+len("@@"):index2]
            indent = index*" "

            if keyword == "declarations":

                # declaraction statements
                for p in params:
                    fout.write(f"{indent}{p.get_f90_decl_string()}")

                if not params:
                    # we always make sure there is atleast one variable
                    fout.write(f"{indent}integer, save, public :: a_dummy_var = 0\n")

            elif keyword == "cudaattributes":
                # we no longer do Fortran with CUDA
                pass

            elif keyword == "allocations":
                for p in params:
                    fout.write(p.get_f90_default_string())

            elif keyword == "deallocations":
                for p in params:
                    if p.dtype != "string":
                        fout.write(f"{indent}deallocate({p.name})\n")

            elif keyword == "namelist":
                for p in params:
                    fout.write(f"{indent}namelist /{namelist_name}/ {p.name}\n")

                if not params:
                    fout.write(f"{indent}namelist /{namelist_name}/ a_dummy_var\n")

            elif keyword == "defaults":
                # this is no longer used -- we do the defaults together with allocations
                pass

            elif keyword == "printing":

                fout.write("100 format (1x, a3, 2x, a32, 1x, \"=\", 1x, a)\n")
                fout.write("101 format (1x, a3, 2x, a32, 1x, \"=\", 1x, i10)\n")
                fout.write("102 format (1x, a3, 2x, a32, 1x, \"=\", 1x, g20.10)\n")
                fout.write("103 format (1x, a3, 2x, a32, 1x, \"=\", 1x, l)\n")

                for p in params:
                    if p.dtype == "logical":
                        ltest = f"\n{indent}ltest = {p.name} .eqv. {p.default}\n"
                    else:
                        ltest = f"\n{indent}ltest = {p.name} == {p.default}\n"

                    fout.write(ltest)

                    cmd = "merge(\"   \", \"[*]\", ltest)"

                    if p.dtype == "real":
                        fout.write(f"{indent}write (unit,102) {cmd}, &\n \"{p.name}\", {p.name}\n")

                    elif p.dtype == "string":
                        fout.write(f"{indent}write (unit,100) {cmd}, &\n \"{p.name}\", trim({p.name})\n")

                    elif p.dtype == "integer":
                        fout.write(f"{indent}write (unit,101) {cmd}, &\n \"{p.name}\", {p.name}\n")

                    elif p.dtype == "logical":
                        fout.write(f"{indent}write (unit,103) {cmd}, &\n \"{p.name}\", {p.name}\n")

                    else:
                        print(f"write_probin.py: invalid datatype for variable {p.name}")


            elif keyword == "acc":
                # we no longer do Fortran openacc
                pass

            elif keyword == "cxx_gets":
                # this writes out the Fortran functions that can be
                # called from C++ to get the value of the parameters

                for p in params:
                    fout.write(p.get_f90_get_function())

            elif keyword == "fortran_parmparse_overrides":

                namespaces = {q.namespace for q in params}
                for nm in namespaces:
                    params_nm = [q for q in params if q.namespace == nm]

                    fout.write(f'    call amrex_parmparse_build(pp, "{nm}")\n')

                    for p in params_nm:
                        fout.write(p.get_query_string("F90"))

                    fout.write('    call amrex_parmparse_destroy(pp)\n')

                    fout.write("\n\n")

        else:
            fout.write(line)

    print(" ")
    fout.close()

    # now handle the C++ -- we need to write a header and a .cpp file
    # for the parameters + a _F.H file for the Fortran communication

    # first the _F.H file
    ofile = f"{cxx_prefix}_parameters_F.H"
    with open(ofile, "w") as fout:
        fout.write(CXX_F_HEADER)

        for p in params:
            if p.dtype == "string":
                fout.write(f"  void get_f90_{p.name}(char* {p.name});\n\n")
                fout.write(f"  void get_f90_{p.name}_len(int& slen);\n\n")

            else:
                fout.write(f"  void get_f90_{p.name}({p.get_cxx_decl()}* {p.name});\n\n")

        fout.write(CXX_F_FOOTER)

    # now the main C++ header with the global data
    cxx_base = os.path.basename(cxx_prefix)

    ofile = f"{cxx_prefix}_parameters.H"
    with open(ofile, "w") as fout:
        fout.write(CXX_HEADER)

        fout.write(f"  void init_{cxx_base}_parameters();\n\n")

        for p in params:
            fout.write(f"  {p.get_decl_string()}")

        fout.write(CXX_FOOTER)

    # now the C++ job_info tests
    ofile = f"{cxx_prefix}_job_info_tests.H"
    with open(ofile, "w") as fout:
        for p in params:
            fout.write(p.get_job_info_test(lang="C++"))

    # finally the C++ initialization routines
    ofile = f"{cxx_prefix}_parameters.cpp"
    with open(ofile, "w") as fout:
        fout.write(f"#include <{cxx_base}_parameters.H>\n")
        fout.write(f"#include <{cxx_base}_parameters_F.H>\n\n")
        fout.write("#include <AMReX_ParmParse.H>\n\n")

        for p in params:
            fout.write(f"  {p.get_declare_string()}")

        fout.write("\n")
        fout.write(f"  void init_{cxx_base}_parameters() {{\n")

        # first write the "get" routines to get the parameter from the
        # Fortran read -- this will either be the default or the value
        # from the probin

        fout.write("    // get the values of the parameters from Fortran\n\n")

        for p in params:
            if p.dtype == "string":
                fout.write(f"    int slen_{p.name} = 0;\n")
                fout.write(f"    get_f90_{p.name}_len(slen_{p.name});\n")
                fout.write(f"    char _{p.name}[slen_{p.name}+1];\n")
                fout.write(f"    get_f90_{p.name}(_{p.name});\n")
                fout.write(f"    {p.name} = std::string(_{p.name});\n\n")
            else:
                fout.write(f"    get_f90_{p.name}(&{p.name});\n\n")


        # now write the parmparse code to get the value from the C++
        # inputs.  this will overwrite

        fout.write("    // get the value from the inputs file (this overwrites the Fortran value)\n\n")

        namespaces = {q.namespace for q in params}

        for nm in namespaces:
            params_nm = [q for q in params if q.namespace == nm]

            # open namespace
            fout.write("    {\n")
            fout.write(f"      amrex::ParmParse pp(\"{nm}\");\n")
            for p in params_nm:
                qstr = p.get_query_string("C++")
                fout.write(f"      {qstr}")
            fout.write("    }\n")

        # have Fortran

        fout.write("  }\n")

def main():

    parser = argparse.ArgumentParser()
    parser.add_argument('-t', type=str, help='probin_template')
    parser.add_argument('-o', type=str, help='out_file')
    parser.add_argument('-n', type=str, help='namelist_name')
    parser.add_argument('--pa', type=str, help='parameter files')
    parser.add_argument('--cxx_prefix', type=str, default="extern",
                        help="a name to use in the C++ file names")

    args = parser.parse_args()

    probin_template = args.t
    out_file = args.o
    namelist_name = args.n
    param_files_str = args.pa

    if (probin_template == "" or out_file == "" or namelist_name == ""):
        sys.exit("write_probin.py: ERROR: invalid calling sequence")

    param_files = param_files_str.split()

    write_probin(probin_template, param_files,
                 namelist_name, out_file, args.cxx_prefix)

if __name__ == "__main__":
    main()
