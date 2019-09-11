// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See VVortex.h for the primary calling header

#ifndef _VVortex_VX_inst_meta_inter_H_
#define _VVortex_VX_inst_meta_inter_H_

#include "verilated.h"

class VVortex__Syms;

//----------

VL_MODULE(VVortex_VX_inst_meta_inter) {
  public:
    
    // PORTS
    
    // LOCAL SIGNALS
    // Begin mtask footprint  all: 
    VL_SIG8(valid,3,0);
    
    // LOCAL VARIABLES
    
    // INTERNAL VARIABLES
  private:
    VVortex__Syms* __VlSymsp;  // Symbol table
  public:
    
    // PARAMETERS
    
    // CONSTRUCTORS
  private:
    VL_UNCOPYABLE(VVortex_VX_inst_meta_inter);  ///< Copying not allowed
  public:
    VVortex_VX_inst_meta_inter(const char* name="TOP");
    ~VVortex_VX_inst_meta_inter();
    
    // API METHODS
    
    // INTERNAL METHODS
    void __Vconfigure(VVortex__Syms* symsp, bool first);
  private:
    void _ctor_var_reset() VL_ATTR_COLD;
} VL_ATTR_ALIGNED(128);

#endif // guard