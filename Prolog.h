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
#include <cstdint>
#include <iostream>
#include <sstream>
#include <cstdio>

#define HASGC 1

const static int64_t STACK_SIZES=200000000;

static const uint8_t TAG_VREF=0b000;
static const uint8_t TAG_VAR=0b001;
static const uint8_t TAG_EOL=0b010;
static const uint8_t TAG_INTEGER=0b011;
static const uint8_t TAG_LIST=0b110;
static const uint32_t TAG_MASK=0b111;
static const uint32_t TAG_WIDTH=3;

#ifdef __OPTIMIZE__
const static uint64_t SP_BUFFER=48;
#else
const static uint64_t SP_BUFFER=128;
#endif
//const static uint64_t SP_BUFFER=1000000;

struct FrameReferenceInfo {
    FrameReferenceInfo(uint32_t p) {count=p;};
    uint32_t count;
};

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
    uint32_t size;
    int32_t clause_index;
    uint32_t parent_frame;
    // Fields up to here must not be altered as there are assembler offsets into them
    int32_t clause_count;
    uint8_t* stack_bottom;
    uint32_t unwind_stack_decouple_mark;
    uint32_t unwind_stack_gc_mark;
    uint32_t call_depth;
    uint8_t* low_water_mark_sp;
};

class List {
public:
    uint32_t head;
    uint32_t tail;
};

class Prolog {
public:
    // Fields beyond here must not be altered as there are assembler offsets into them
    FrameStore* frames=(FrameStore*)malloc(1000*sizeof(FrameStore));
    uint32_t frame_top;
    uint32_t frame_size=sizeof(FrameStore);
    uint32_t* scratch_buf=(uint32_t*)malloc(0x40000);
    // Fields up to here must not be altered as there are assembler offsets into them
    inline void pointer_chase(uint8_t& tag, uint32_t& val) {
loop:
        uint32_t v;
        tag=(val&TAG_MASK);
        if(((tag&TAG_MASK)==TAG_VREF) && (v=variables[(val>>TAG_WIDTH)])!=TAG_VAR) {
            val=v;
            goto loop;
        }
    }
    inline void pointer_chase_notag(uint32_t& val) {
loop:
        uint32_t v;
        uint8_t tag=(val&TAG_MASK);
        if(((tag&TAG_MASK)==TAG_VREF) && (v=variables[(val>>TAG_WIDTH)])!=TAG_VAR) {
            val=v;
            goto loop;
        }
    }
    bool unify(uint32_t val1, uint32_t val2);
    inline uint32_t get_list_cell() {
        if(freelist_list==0) {
            unwind_stack_gc[top_unwind_stack_gc++]=top_list_values;
            //std::cout << "get_list_cellA:" << top_list_values << std::endl;
            return top_list_values++;
        }
        uint32_t ret=freelist_list;
        freelist_list=list_values[freelist_list].head;
        unwind_stack_gc[top_unwind_stack_gc++]=ret;
        //std::cout << "get_list_cellB:" << ret << std::endl;
        return ret;
    }
    void delete_list_cell(uint32_t cell) {
        //std::cout << "delete_list_cell:" << cell << std::endl;
        list_values[cell].head=freelist_list;
        freelist_list=cell;
    }
    void __do_start();
    uint32_t plcreate_eol();
    uint32_t plcreate_int(uint32_t i);
    uint32_t plcreate_var(uint32_t i);
    uint32_t plcreate_list(uint32_t h, uint32_t t) {
        uint32_t l=get_list_cell();
        list_values[l].head=h;
        list_values[l].tail=t;
        return (l<<TAG_WIDTH)+TAG_LIST;
    }
    std::string pldisplay(uint32_t x);
    void process_stack_state(FrameStore* fs);
    FrameStore* process_stack_state_load_save(int flag);
    void process_stack_state_save_aux(FrameStore* fs);
    uint32_t process_stack_state_load_aux(uint32_t parent);
    void pop_frame_stack();
    void pop_frame_stack_track_parent(uint32_t& parent);
    void unwind_stack_revert_to_mark(uint32_t decouple_mark, uint32_t gc_mark, uint32_t call_depth, uint32_t& parent);
    void pldisplay_aux(std::stringstream& ss, char ch, bool in_list, uint32_t i);
    inline void var_set_add_to_unwind_stack(uint32_t v, uint32_t val) {
        //if((val&TAG_MASK)==TAG_LIST)std::cout << "tag: " << v << ":" << val << std::endl;
        variables[v]=val;
        unwind_stack_decouple[top_unwind_stack_decouple++]=v;
    };
    inline void var_set_add_to_unwind_stack_nogc(uint32_t v, uint32_t val) {
        variables[v]=val;
        unwind_stack_decouple[top_unwind_stack_decouple++]=v;
    };
    inline void unwind_stack_revert_to_mark_only(uint32_t bottom_decouple, uint32_t bottom_gc) {
        //std::cout << bottom_decouple << "::" << top_unwind_stack_decouple << "  ";
        for(uint32_t i=bottom_decouple;i<top_unwind_stack_decouple;i++) {
            //std::cout << (((variables[var]&TAG_MASK)==TAG_LIST)?1:0);
            variables[unwind_stack_decouple[i]]=TAG_VAR;
        }
        //std::cout << std::endl;
        top_unwind_stack_decouple=bottom_decouple;
        for(uint32_t i=bottom_gc;i<top_unwind_stack_gc;i++) {
            delete_list_cell(unwind_stack_gc[i]);
       }
        top_unwind_stack_gc=bottom_gc;
    };
    inline void set_stack_low_water_mark() {
#ifdef __OPTIMIZE__
        uint8_t* sp=(uint8_t*)__builtin_frame_address(0);
#else
        uint8_t* sp=(uint8_t*)__builtin_frame_address(1);
#endif
        if(frames[frame_top].low_water_mark_sp<sp) {
            frames[frame_top].low_water_mark_sp=sp;
        }
        Prolog::check_stack();
   }
    void check_stack() {
        // if(frame_top>0) {
        // FrameStore* fs_low=&frames[frame_top];
        // int32_t i=fs_low->size-1;
        // while(fs_low->store[i]==fs_low->live[i] && i>=0) {
        //     i--;
        // }
        // std::cout << "Actual_sp " << (void*)(fs_low->live+i) << " (" << (int32_t)(frames[frame_top].low_water_mark_sp-(fs_low->live+i)) << ')' << std::endl;
        // }
    }
    uint8_t* base_sp=0;
    uint8_t* stack_storage=(uint8_t*)aligned_alloc(0x20,STACK_SIZES);
    uint32_t* variables=(uint32_t*)malloc(4*STACK_SIZES);
    uint32_t* unwind_stack_decouple=(uint32_t*)malloc(4*STACK_SIZES);
    uint32_t* unwind_stack_gc=(uint32_t*)malloc(4*STACK_SIZES);
    uint32_t top_unwind_stack_decouple=0;
    uint32_t top_unwind_stack_gc=0;
    uint32_t stack_used=0;
    uint32_t top_variables=0;
    uint32_t top_list_values=1; // don't use 0, so that can be freelist stop
    uint32_t static_list_variables;
    uint32_t freelist_list=0;
    uint32_t function_frame_top_last_n_clause;
    List* list_values=(List*)malloc(STACK_SIZES*sizeof(List));
};
