// BSD 3-Clause License
//
// Copyright (c) 2024, Roy Ward
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#pragma once
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "PrologGenerated.h"

#define HASGC 1

const static int64_t STACK_SIZES=200000000;

static const uint8_t TAG_VREF=0b000;
static const uint8_t TAG_VAR=0b001;
static const uint8_t TAG_EOL=0b010;
static const uint8_t TAG_INTEGER=0b011;
static const uint8_t TAG_LIST=0b110;
static const UWORD TAG_MASK=0b111;
static const uint32_t TAG_WIDTH=3;

// #ifdef __OPTIMIZE__
// const static uint64_t SP_BUFFER=48;
// #else
// const static uint64_t SP_BUFFER=128;
// #endif
// //const static uint64_t SP_BUFFER=1000000;

#ifdef __OPTIMIZE__
//const static UWORD STACK_SAVE_OFFSET=96;
const static UWORD STACK_SAVE_OFFSET=136;
#else
#ifdef WORD64
const static UWORD STACK_SAVE_OFFSET=136;
#else
const static UWORD STACK_SAVE_OFFSET=108;
#endif
#endif

struct FrameStore {
    // Fields beyond here must not be altered as there are assembler offsets into them
    uint8_t* store_bx;
    uint8_t* store_sp;
    uint8_t* store_bp;
    uint8_t* store_12;
    uint8_t* store_13;
    uint8_t* store_14;
    uint8_t* store_15;
    uint8_t* store;
    uint8_t* live;
    uint32_t save_size;
    int32_t clause_index;
    uint32_t parent_frame;
    // Fields up to here must not be altered as there are assembler offsets into them
    uint32_t load_size;
    int32_t clause_count;
    uint8_t* stack_bottom;
    UWORD unwind_stack_decouple_mark;
    UWORD unwind_stack_gc_mark;
    uint32_t call_depth;
    uint8_t* low_water_mark_sp;
};

struct List {
    UWORD head;
    UWORD tail;
};

struct Prolog {
    // Fields beyond here must not be altered as there are assembler offsets into them
    FrameStore* frames;
    uint32_t frame_top;
    uint32_t frame_size;
    //uint32_t* scratch_buf=(uint32_t*)malloc(0x40000);
    // Fields up to here must not be altered as there are assembler offsets into them
    uint8_t* base_sp;
    uint8_t* stack_storage;
    UWORD* variables;
    UWORD* unwind_stack_decouple;
    UWORD* unwind_stack_gc;
    UWORD top_unwind_stack_decouple;
    UWORD top_unwind_stack_gc;
    UWORD stack_used;
    UWORD top_variables;
    UWORD top_list_values;; // don't use 0, so that can be freelist stop
    UWORD static_list_variables;
    UWORD freelist_list;
    uint32_t function_frame_top_last_n_clause;
    List* list_values;
};

void init(Prolog* p);
bool unify(Prolog* p, UWORD val1, UWORD val2);
void __do_start(Prolog* p);
UWORD plcreate_eol();
UWORD plcreate_int(UWORD i);
UWORD plcreate_var(Prolog* p, UWORD i);
char* pldisplay(Prolog* p, UWORD x);
void process_stack_state(Prolog* p, FrameStore* fs);
FrameStore* process_stack_state_load_save(Prolog* p, int flag);
void process_stack_state_save_aux(Prolog* p);
void process_stack_state_load_aux(Prolog* p);
void pop_frame_stack(Prolog* p);
void pop_frame_stack_track_parent(Prolog* p, uint32_t* parent);
void unwind_stack_revert_to_mark(Prolog* p, UWORD decouple_mark, UWORD gc_mark, uint32_t call_depth, uint32_t* parent);
//void pldisplay_aux(Prolog* p, std::stringstream& ss, char ch, bool in_list, UWORD i);

inline void check_stack(Prolog*) {}

inline void pointer_chase(Prolog* p, uint8_t* tag, UWORD* val) {
loop:
    UWORD v;
    *tag=(*val&TAG_MASK);
    if(((*tag&TAG_MASK)==TAG_VREF) && (v=p->variables[(*val>>TAG_WIDTH)])!=TAG_VAR) {
        *val=v;
        goto loop;
    }
}

inline void pointer_chase_notag(Prolog* p, UWORD* val) {
loop:
    UWORD v;
    uint8_t tag=(*val&TAG_MASK);
    if(((tag&TAG_MASK)==TAG_VREF) && (v=p->variables[(*val>>TAG_WIDTH)])!=TAG_VAR) {
        *val=v;
        goto loop;
    }
}

inline UWORD get_list_cell(Prolog* p) {
    if(p->freelist_list==0) {
        p->unwind_stack_gc[p->top_unwind_stack_gc++]=p->top_list_values;
        //std::cout << "get_list_cellA:" << top_list_values << std::endl;
        return p->top_list_values++;
    }
    UWORD ret=p->freelist_list;
    p->freelist_list=p->list_values[p->freelist_list].head;
    p->unwind_stack_gc[p->top_unwind_stack_gc++]=ret;
    //std::cout << "get_list_cellB:" << ret << std::endl;
    return ret;
}

inline UWORD plcreate_list(Prolog* p, UWORD h, UWORD t) {
    UWORD l=get_list_cell(p);
    p->list_values[l].head=h;
    p->list_values[l].tail=t;
    return (l<<TAG_WIDTH)+TAG_LIST;
}

inline void delete_list_cell(Prolog* p, UWORD cell) {
    //std::cout << "delete_list_cell:" << cell << std::endl;
    p->list_values[cell].head=p->freelist_list;
    p->freelist_list=cell;
}

inline void var_set_add_to_unwind_stack(Prolog* p, UWORD v, UWORD val) {
    //if((val&TAG_MASK)==TAG_LIST)std::cout << "tag: " << v << ":" << val << std::endl;
    p->variables[v]=val;
    p->unwind_stack_decouple[p->top_unwind_stack_decouple++]=v;
}

inline void var_set_add_to_unwind_stack_nogc(Prolog* p, UWORD v, UWORD val) {
    p->variables[v]=val;
    p->unwind_stack_decouple[p->top_unwind_stack_decouple++]=v;
}

inline void unwind_stack_revert_to_mark_only(Prolog* p, UWORD bottom_decouple, UWORD bottom_gc) {
    //std::cout << bottom_decouple << "::" << top_unwind_stack_decouple << "  ";
    for(UWORD i=bottom_decouple;i<p->top_unwind_stack_decouple;i++) {
        //std::cout << (((variables[var]&TAG_MASK)==TAG_LIST)?1:0);
        p->variables[p->unwind_stack_decouple[i]]=TAG_VAR;
    }
    //std::cout << std::endl;
    p->top_unwind_stack_decouple=bottom_decouple;
    for(UWORD i=bottom_gc;i<p->top_unwind_stack_gc;i++) {
        delete_list_cell(p,p->unwind_stack_gc[i]);
    }
    p->top_unwind_stack_gc=bottom_gc;
}

inline void set_stack_low_water_mark(Prolog* p) {
#ifdef __OPTIMIZE__
    uint8_t* sp=(uint8_t*)__builtin_frame_address(0);
#else
    uint8_t* sp=(uint8_t*)__builtin_frame_address(1);
#endif
    if(p->frames[p->frame_top].low_water_mark_sp<sp) {
        p->frames[p->frame_top].low_water_mark_sp=sp;
    }
    //std::cout << "lwm=" << frame_top << '/' << (void*)frames[frame_top].low_water_mark_sp << std::endl;
    check_stack(p);
}
