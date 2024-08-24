#pragma once
#include <cstdint>
#include <iostream>
#include <sstream>

const static int64_t STACK_SIZES=100000000;

static const uint8_t TAG_VREF=0b001;
static const uint8_t TAG_LIST=0b010;
static const uint8_t TAG_EOL=0b110;
static const uint8_t TAG_INTEGER=0b100;
static const uint32_t TAG_MASK=0b111;
static const uint32_t TAG_WIDTH=3;

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
    uint64_t* store;
    uint64_t* live;
    uint32_t size;
    int32_t clause_index;
    // Fields up to here must not be altered as there are assembler offsets into them
    uint8_t* stack_bottom;
    //uint8_t* stack_top;
    int32_t clause_count;
    //uint32_t frame_index;
    uint32_t frame_top_unwind_stack_decouple_mark;
    uint32_t
    uint32_t call_depth=0;
};

class List {
public:
    
    uint32_t head;
    uint32_t tail;
};

class Prolog {
public:
    inline void pointer_chase(uint8_t& tag, uint32_t& val) {
        uint32_t v;
        while((val&TAG_MASK)==TAG_VREF && (v=variables[(val>>TAG_WIDTH)])!=0) {
            val=v;
        }
        tag=(val&TAG_MASK);
    }
    bool unify(uint32_t val1, uint32_t val2);
    inline uint32_t get_list_cell() {
        if(freelist_list==0) {
            return top_list_values++;
        }
        uint32_t ret=freelist_list;
        freelist_list=list_values[freelist_list].head;
        return ret;
    }
    void delete_list_cell(uint32_t cell);
    void __do_start();
    uint32_t plcreate_eol();
    uint32_t plcreate_int(uint32_t i);
    uint32_t plcreate_var(uint32_t i);
    uint32_t plcreate_list(uint32_t h, uint32_t t);
    std::string pldisplay(uint32_t x);
    void process_stack_state(FrameStore* fs);
    FrameStore* process_stack_state_load_save(FrameStore* fs);
    void process_stack_state_save_aux(FrameStore* fs);
    FrameStore* process_stack_state_load_aux();
    void pop_frame_stack(FrameStore* fs);
    void unwind_stack_mark();
    void unwind_stack_revert_to_mark();
    void pldisplay_aux(std::stringstream& ss, char ch, bool in_list, uint32_t i);

    uint8_t* base_sp=0;
    FrameStore* frames=new FrameStore[1000];
    uint8_t* stack_storage=new uint8_t[STACK_SIZES];
    uint32_t* variables=new uint32_t[STACK_SIZES]();
    //uint32_t* unwind_stack_decouple_mark=new uint32_t[STACK_SIZES];
    uint32_t* unwind_stack_decouple=new uint32_t[STACK_SIZES];
    //uint32_t top_unwind_stack_decouple_mark=0;
    uint32_t top_unwind_stack_decouple=0;
    uint32_t frame_count=0;
    uint32_t stack_used=0;
    uint32_t top_variables=0;
    uint32_t top_list_values=1; // don't use 0, so that can be freelist stop
    uint32_t freelist_list=0;
    List* list_values=new List[STACK_SIZES];
};
