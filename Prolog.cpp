#include <immintrin.h>
#include <cstdio>

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

#include "Prolog.h"
#include <sstream>
#include <cstring>

//#define D 1

bool Prolog::unify(UWORD val1, UWORD val2) {
    // No pointer chasing. Assumed already done
    uint8_t tag1=val1&TAG_MASK;
    //pointer_chase(tag1,val1);
    uint8_t tag2=val2&TAG_MASK;;
    //pointer_chase(tag2,val2);
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
    if(tag1!=tag2 && tag1+tag2!=13) {
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

UWORD Prolog::plcreate_eol() {
    return TAG_EOL;
}

UWORD Prolog::plcreate_int(UWORD i) {
    return (i<<TAG_WIDTH)+TAG_INTEGER;
}

UWORD Prolog::plcreate_var(UWORD i) {
    if(top_variables<i+1) {
        top_variables=i+1;
    }
    return (i<<TAG_WIDTH)+TAG_VREF;
}

std::string Prolog::pldisplay(UWORD i) {
    std::stringstream ss;
    pldisplay_aux(ss,' ',false,i);
    return ss.str();
}

void Prolog::pldisplay_aux(std::stringstream& ss, char ch, bool in_list, UWORD i) {
    uint8_t tag;
    pointer_chase(tag,i);
    if(tag==TAG_EOL && in_list) {
        return;
    }
    UWORD v=i>>TAG_WIDTH;
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

void __attribute__ ((noinline)) Prolog::process_stack_state_save_aux() {
    FrameStore* fs=&frames[frame_top];
    // uint8_t* sp;
    // asm ("mov %%rsp, %0"
    // : "=r" (sp)
    // : );
    //fs->lwm=low_water_mark_sp;
    uint64_t extra=((uint64_t)fs->store_sp)&SSE_ALIGN;
    fs->stack_bottom=(fs->store_sp-extra);
    fs->live=(fs->stack_bottom);
    //uint8_t* top_sp=base_sp;
    //uint8_t* top_sp=std::min(base_sp,frames[fs->parent_frame].store_sp+SP_BUFFER);
    fs->save_size=((base_sp-fs->stack_bottom)+SSE_ALIGN)&~SSE_ALIGN;
    fs->load_size=fs->save_size;
    fs->store=(&stack_storage[STACK_SIZES-stack_used-fs->save_size]);
    if(frame_top>1 && fs->low_water_mark_sp!=0/* && fs->low_water_mark_sp!=base_sp*/) {
        FrameStore* fsl=&frames[frame_top-1];
        uint8_t* i0=fs->live+fs->save_size;
        uint8_t* i1=fsl->store+fsl->save_size;
        uint32_t acc=0;
        while(*--i0 == *--i1) {
            acc++;
        }
        //std::cout << "acc=" << acc << std::endl;
        uint8_t* acc_lwm=fs->live+fs->save_size-acc;
#if D
        std::cout << "DIFFS(" << frame_top << ") " << (void*)acc_lwm << ':' << (void*)(fs->low_water_mark_sp+STACK_SAVE_OFFSET) << "   " << (int32_t)(fs->low_water_mark_sp+STACK_SAVE_OFFSET-acc_lwm) << std::endl;
#endif
        //if((int32_t)(acc_lwm-fs->low_water_mark_sp)<0)asm("int3");
        // int32_t i=fs->size-1;
        // while(fs_low->store[i]==fs->live[i] && i>=0) {
        //     i--;
        // }
    }
    uint8_t* local_low_water_mark=(fs->low_water_mark_sp!=nullptr && frame_top>1)?fs->low_water_mark_sp:base_sp;
#if D
    std::cout << "SAVE SIZE: " << fs->save_size << " -> ";
#endif
//    fs->save_size=((std::min(base_sp,local_low_water_mark+STACK_SAVE_OFFSET)-fs->stack_bottom)+SSE_ALIGN)&~SSE_ALIGN;
#if D
    std::cout << fs->save_size << std::endl;
#endif
    if(fs->live+fs->save_size<base_sp) {
        int32_t fptr=frame_top-1;
        while(fptr>0) {
            FrameStore& fsl=frames[fptr];
            if(fsl.live+fsl.save_size>fs->live+fs->save_size) {
#if D
                std::cout << "PTR " << frame_top << "->" << fptr << std::endl;
#endif
                fs->parent_frame=fptr;
                break;
            }
            fptr--;
        }
    } else {
        fs->parent_frame=0;
    }
    stack_used+=fs->save_size;
    uint64_t save_size=fs->save_size;
    uint8_t* dst=fs->store;
    uint8_t* src=fs->live;
#if D
    std::cout << frame_top << '$' << (void*)src << ':' << (void*)(src+save_size) << std::endl;
#endif
    //std::cout << size << std::endl;
    for(UWORD i=0;i<save_size;i+=(SSE_ALIGN+1)) {
#ifdef USE_AVX
        _mm256_store_ps((float*)(dst+i),_mm256_load_ps((float*)(src+i)));
#else
       _mm_store_ps((float*)(dst+i),_mm_load_ps((float*)(src+i)));
#endif
    }
    //std::cout << "==================== save " << frame_top << "  lwm=" << (void*)fs->low_water_mark_sp << std::endl;
    //std::cout << "LWM " << (void*)sp << std::endl;
    fs->unwind_stack_decouple_mark=top_unwind_stack_decouple;
    fs->unwind_stack_gc_mark=top_unwind_stack_gc;
    fs->low_water_mark_sp=0;
}

uint32_t c=0;

void __attribute__ ((noinline)) Prolog::process_stack_state_load_aux() {
    // Subsequent pass - restore the data
    FrameStore* fs_low=&frames[frame_top];
    if(fs_low->unwind_stack_decouple_mark<top_unwind_stack_decouple) {
        UWORD bottom_decouple=fs_low->unwind_stack_decouple_mark;
        UWORD bottom_gc=fs_low->unwind_stack_gc_mark;
        unwind_stack_revert_to_mark_only(bottom_decouple,bottom_gc);
    }
    int32_t i=fs_low->load_size-1;
    while(fs_low->store[i]==fs_low->live[i] && i>=0) {
       i--;
    }
    //std::cout << "actual_sp " << (void*)(fs_low->live+i) << std::endl;
    //std::cout << "==================== load " << frame_top << "  lwm=" << (void*)fs_low->low_water_mark_sp << std::endl;
    //asm("int3");
    // uint32_t frame_count=0;
    // scratch_buf[frame_count*3]=frame_top;
    // scratch_buf[frame_count*3+1]=fs_low->save_size;
    // scratch_buf[frame_count*3+2]=0;
    // frame_count++;
    uint8_t* src=fs_low->store;
    uint8_t* dst=fs_low->live;
    uint32_t size=fs_low->save_size;
    for(UWORD i=0;i<size;i+=(SSE_ALIGN+1)) {
#ifdef USE_AVX
        _mm256_store_ps((float*)(dst+i),_mm256_load_ps((float*)(src+i)));
#else
        _mm_store_ps((float*)(dst+i),_mm_load_ps((float*)(src+i)));
#endif
    }
    uint32_t fptr=frame_top;
    uint8_t* current_top=fs_low->live+fs_low->save_size;
    while(current_top<base_sp) {
        fptr--;
        FrameStore fsptr=frames[fptr];
        if(fsptr.live+fsptr.save_size>current_top) {
            uint32_t new_size=fsptr.live+fsptr.save_size-current_top;
            uint32_t new_offset=fsptr.save_size-new_size;
            current_top=fsptr.live+fsptr.save_size;
            uint8_t* src=fsptr.store+new_offset;
            uint8_t* dst=fsptr.live+new_offset;
            for(UWORD i=0;i<new_size;i+=(SSE_ALIGN+1)) {
#ifdef USE_AVX
                _mm256_store_ps((float*)(dst+i),_mm256_load_ps((float*)(src+i)));
#else
                _mm_store_ps((float*)(dst+i),_mm_load_ps((float*)(src+i)));
#endif
            }
            // scratch_buf[frame_count*3]=fptr;
            // scratch_buf[frame_count*3+1]=new_size;
            // scratch_buf[frame_count*3+2]=new_offset;
            //frame_count++;
#if D
            std::cout << "%%%%%%%%%%% " << fptr << ' ' << new_size << ' ' << new_offset << std::endl;
#endif
        }
    }
    //scratch_buf[frame_count++]=std::min((((uint32_t)(fs_low->low_water_mark_sp-fs_low->live))+SSE_ALIGN)&~SSE_ALIGN,fs_low->size);
    // while(fs_low->parent_frame!=0/* && fs_low->parent_frame>=parent*/) {
    //     scratch_buf[frame_count++]=fs_low->parent_frame;
    //     fs_low=&frames[fs_low->parent_frame];
    // }
    uint8_t* actual=fs_low->live+i;
    //std::cout << "ACTUAL_SP " << (void*)(actual) << std::endl;
#if D
    std::cout << "DIFF " << (int32_t)(fs_low->low_water_mark_sp-actual) << std::endl;
#endif
    //if((int32_t)(low_water_mark_sp-actual)<-200)asm("int3");
    //std::cout << fs_low->size << ':' << (int64_t)(low_water_mark_sp-fs_low->live) << ':' << i << "   " << i-(int32_t)(low_water_mark_sp-fs_low->live) << std::endl;
    //if(c>=7)asm("int3");
    c++;
    //asm("int3");
    // std::cout << (void*)base_sp << std::endl;
    // for(int32_t i=frame_count-1;i>=0;i--) {
    //     std::cout << scratch_buf[i*3] << "#" << (void*)(frames[scratch_buf[i*3]].live+scratch_buf[i*3+2])
    //         << ':' << (void*)(frames[scratch_buf[i*3]].live+scratch_buf[i*3+2]+scratch_buf[i*3+1]) << std::endl;
    // }
    // printf("\n");
#if TRACE
    printf("%d  ",parent);
    for(int32_t i=frame_count-1;i>=0;i--) {
        printf(",%d",scratch_buf[i]);
    }
    printf("\n");
#endif
}

void Prolog::pop_frame_stack() {
    while(frame_top>0 && frames[frame_top].clause_index==frames[frame_top].clause_count) {
        stack_used-=frames[frame_top].save_size;
#if TRACE
//        printf(" -%d\n",frame_top);
#endif
        frame_top--;
    }
}

// void Prolog::pop_frame_stack_track_parent(uint32_t &parent) {
//     while(frame_top>0 && frames[frame_top].clause_index==frames[frame_top].clause_count) {
//         if(parent==frame_top) {
//             parent=frames[frame_top].parent_frame;
//         }
//         stack_used-=frames[frame_top].size;
// #if TRACE
// //        printf(" -%d\n",frame_top);
// #endif
//         frame_top--;
//     }
// }

void Prolog::unwind_stack_revert_to_mark(UWORD bottom_decouple, UWORD bottom_gc, uint32_t frame_depth, uint32_t& parent) {
    pop_frame_stack();
    //pop_frame_stack_track_parent(parent);
    if(frame_top>0 && frame_depth<frame_top) {
#if TRACE
        std::cout << "=== loaded continuation0 " << frame_top << std::endl;
#endif
        process_stack_state_load_save(frame_top);
    }
    unwind_stack_revert_to_mark_only(bottom_decouple,bottom_gc);
    //top_unwind_stack_decouple=bottom_decouple;
    //top_unwind_stack_gc=bottom_gc;
}

int main() {
    Prolog p;
    p.__do_start();
    p.unwind_stack_revert_to_mark_only(0,0);
#ifdef TEST_GC
    UWORD acc=0;
    UWORD v=p.freelist_list;
    while(v!=0) {
        acc++;
        v=p.list_values[v].head;
    }
    std::cout << "Used list cells=" <<acc<<std::endl;
    std::cout << "Max list cells=" <<p.top_list_values-p.static_list_variables<<std::endl;
#endif
    return 0;
}
