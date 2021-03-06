# aprox13

This is a rewrite of Frank Timmes' aprox13 network.  The ``aprox13.tbz``
was initially downloaded from his website on 2013-03-18, and we last
synced with the public version on 2016-01-08. We want to make it 

#. threadsafe

#. use VODE

#. work with an SDC methodology.

This version integrates the 13 species equations, a temperature equation
(to get the temperature for rate evaluations), and an enuc equation
(to accumulate the amount of energy generated over the step)


We mainly need from his package the following:

  * RHS routines

  * screening routines

  * plasma neutrino loss routines

  * final energy generation routine

In particular, the following routines from the original package 
are not used:

  * screen6 (never seems to have been called.  screen5 is used instead)

  * snupp, snucno -- these are neutrino loss routines for H burning -- we
    are not modeling that

  * netint and all of the ma28 stuff -- we are using VODE

  * ecapnuc*, mazurek -- no electron captures

  * *wien*

  * most of the rate_* routines -- we only need the ones specific to this
    network


Modifications:

  * we made a derived type call tf_t that holds all the various
    temperature factors.  This way we can eliminate those common
    blocks.

  * ``screen5`` caches the old temperature information to allow it
    to save on recomputing the plasma factors.  This is not
    threadsafe. We created a derived type to store these factors and
    fill it once upon entering the screening routine.

    We also moved it into a screening module that allowed us to store
    a number of its variables as module data, which are now computed
    once at the beginning of the simulation.

We thank Frank for allowing us to redistribute these routines.
