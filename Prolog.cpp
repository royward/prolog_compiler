#include <immintrin.h>

/*
Data structures:
uint32_t variables[]
uint64_t list_values[]
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

uint32_t unwind_stack_decouple[]
uint32_t unwind_stack_delete[]
Tags in low bits - tags are not for that type, but for the type that it is pointing to:
......000 vref (chase these ones)
......001 ununified vref
......010 list
......110 eol
......100 integer
*/
// pre: tag2:001, &val2=0
// pre: tag1:100, val1=value;
#include "Prolog.h"
#include <sstream>
#include <cstring>

bool Prolog::unify(uint32_t val1, uint32_t val2) {
    // First do any pointer chasing. There may be benefits to checking variable matching first
    uint8_t tag1;
    pointer_chase(tag1,val1);
    uint8_t tag2;
    pointer_chase(tag2,val2);
    if(tag2==TAG_VREF) {
        variables[(val2>>TAG_WIDTH)]=val1;
        unwind_stack_decouple[top_unwind_stack_decouple++]=val2>>TAG_WIDTH;
        return true;
    }
    if(tag1==TAG_VREF) {
        variables[(val1>>TAG_WIDTH)]=val2;
        unwind_stack_decouple[top_unwind_stack_decouple++]=(val1>>TAG_WIDTH);
        return true;
    }
    if(tag1!=tag2) {
        return false;
    }
    switch(tag1) {
        case TAG_LIST: {
            List& l1=list_values[val1>>TAG_WIDTH];
            List& l2=list_values[val2>>TAG_WIDTH];
            return unify(l1.head,l2.head) && unify(l1.tail,l2.tail);
        } break;
        case TAG_EOL: {
            return true;
        } break;
        case TAG_INTEGER: {
            return val1==val2;
        } break;
        default: return false;
    }
}

void Prolog::delete_list_cell(uint32_t cell) {
    list_values[cell].head=freelist_list;
    freelist_list=cell;
}

uint32_t Prolog::plcreate_eol() {
    return TAG_EOL;
}

uint32_t Prolog::plcreate_int(uint32_t i) {
    return (i<<TAG_WIDTH)+TAG_INTEGER;
}

uint32_t Prolog::plcreate_var(uint32_t i) {
    if(top_variables<i+1) {
        top_variables=i+1;
    }
    return (i<<TAG_WIDTH)+TAG_VREF;
}

uint32_t Prolog::plcreate_list(uint32_t h, uint32_t t) {
    uint32_t l=get_list_cell();
    list_values[l].head=h;
    list_values[l].tail=t;
    return (l<<TAG_WIDTH)+TAG_LIST;
}

std::string Prolog::pldisplay(uint32_t i) {
    std::stringstream ss;
    pldisplay_aux(ss,' ',false,i);
    return ss.str();
}

void Prolog::pldisplay_aux(std::stringstream& ss, char ch, bool in_list, uint32_t i) {
    uint8_t tag;
    pointer_chase(tag,i);
    if(tag==TAG_EOL && in_list) {
        return;
    }
    uint32_t v=i>>TAG_WIDTH;
    if(ch!=' ') {
        ss << ch;
    }
    switch(tag) {
        case TAG_VREF: {
            ss << '_' << v;
        } break;
        case TAG_LIST: {
            if(!in_list) {
                ss << '[';
            }
            List& l=list_values[v];
            pldisplay_aux(ss,' ',false,l.head);
            pldisplay_aux(ss,',',true,l.tail);
            if(!in_list) {
                ss << ']';
            }
        } break;
        case TAG_EOL: {
            if(ch==' ') {
                ss << '[';
            }
            ss << ']';
        } break;
        case TAG_INTEGER: {
            ss << v;
        } break;
        default: {
            ss << "<error>";
        }
    }
}

#ifdef USE_AVX
#define SSE_ALIGN 0x1F
#else
#define SSE_ALIGN 0xF
#endif

void __attribute__ ((noinline)) Prolog::process_stack_state_save_aux(FrameStore* fs) {
    uint64_t extra=((uint64_t)fs->store_sp)&SSE_ALIGN;
    fs->stack_bottom=(fs->store_sp-extra);
    fs->live=(fs->stack_bottom);
    fs->size=((base_sp-fs->stack_bottom)+SSE_ALIGN)&~SSE_ALIGN;
    fs->store=(&stack_storage[STACK_SIZES-stack_used-fs->size]);
    stack_used+=fs->size;
    uint64_t size=fs->size;
    uint8_t* dst=fs->store;
    uint8_t* src=fs->live;
    for(uint32_t i=0;i<size;i+=(SSE_ALIGN+1)) {
#ifdef USE_AVX
        _mm256_store_ps((float*)(dst+i),_mm256_load_ps((float*)(src+i)));
#else
       _mm_store_ps((float*)(dst+i),_mm_load_ps((float*)(src+i)));
#endif
    }
    fs->unwind_stack_decouple_mark=top_unwind_stack_decouple;
}

void __attribute__ ((noinline)) Prolog::process_stack_state_load_aux() {
    // Subsequent pass - restore the data
    FrameStore* fs_low=&frames[frame_count-1];
    if(fs_low->unwind_stack_decouple_mark<top_unwind_stack_decouple) {
        uint32_t bottom=fs_low->unwind_stack_decouple_mark;
        for(uint32_t i=bottom;i<top_unwind_stack_decouple;i++) {
            variables[unwind_stack_decouple[i]]=0;
        }
    }
}

void Prolog::pop_frame_stack(FrameStore*/* fs*/) {
    while(frame_count>0 && frames[frame_count-1].clause_index==frames[frame_count-1].clause_count) {
        stack_used-=frames[frame_count-1].size;
        // if(frames[frame_count-1].call_depth!=0) {
        //     std::cout << "=== popped continuation: " << frame_count << std::endl;
        // }
        frame_count--;
    }
}

void Prolog::unwind_stack_revert_to_mark(uint32_t bottom, uint32_t call_depth) {
    pop_frame_stack(nullptr);
    if(frame_count>0 && call_depth<frames[frame_count-1].call_depth) {
        //std::cout << "Prolog::unwind_stack_revert_to_mark" << std::endl;
        process_stack_state_load_save(nullptr);
    }
    for(uint32_t i=bottom;i<top_unwind_stack_decouple;i++) {
        variables[unwind_stack_decouple[i]]=0;
    }
    top_unwind_stack_decouple=bottom;
}

int main() {
    Prolog p;
    p.__do_start();
    return 0;
}
