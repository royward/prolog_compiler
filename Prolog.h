#pragma once
#include <cstdint>
#include <iostream>
#include <sstream>

const static uint32_t STACK_SIZES=1000000;

static const uint8_t TAG_VREF_UNUNIFIED=0b000;
static const uint8_t TAG_VREF=0b001;
static const uint8_t TAG_LIST=0b010;
static const uint8_t TAG_EOL=0b110;
static const uint8_t TAG_INTEGER=0b100;
static const uint32_t TAG_MASK=0b111;

struct FrameReferenceInfo {
    FrameReferenceInfo(uint32_t p) {count=p;};
    uint32_t count;
};

struct FrameStore {
    uint8_t* store_cx;
    uint8_t* store_dx;
    uint8_t* store_bx;
    uint8_t* store_sp;
    uint8_t* store_bp;
    uint8_t* store_si;
    uint8_t* store_di;
    uint8_t* store_8;
    uint8_t* store_9;
    uint8_t* store_12;
    uint8_t* store_13;
    uint8_t* store_14;
    uint8_t* store_15;
    FrameReferenceInfo* fri=nullptr;
    uint32_t stack_storage_index;
    uint32_t size;
    uint32_t clause_index;
};

class List {
public:
    
    uint32_t head;
    uint32_t tail;
};

class Prolog {
public:
    inline void pointer_chase(uint32_t& val, uint32_t voffset) {
        while((val&TAG_MASK)==0) {
            val=variables[(val>>3)+voffset];
        }
    }
    inline void pointer_chase(uint32_t& val) {
        while((val&TAG_MASK)==0) {
            val=variables[(val>>3)];
        }
    }
    bool unify(uint32_t val1, uint32_t voffset1, uint32_t val2, uint32_t voffset2);
    bool unify(uint32_t val1, uint32_t val2, uint32_t voffset2);
    bool match_eol(uint32_t val);
    bool match_int(uint32_t i,uint32_t val);
    bool match_var(uint32_t v,uint32_t val, uint32_t voffset);
    uint32_t get_list_cell();
    void delete_list_cell(uint32_t cell);
    void __do_start();
    uint32_t plcreate_eol();
    uint32_t plcreate_int(uint32_t i);
    uint32_t plcreate_var(uint32_t i);
    uint32_t plcreate_list(uint32_t h, uint32_t t);
    std::string pldisplay(uint32_t x, uint32_t offset);
    FrameStore* process_stack_state(FrameReferenceInfo* fri);
    void pop_frame_stack();
    void unwind_stack_mark();
    void unwind_stack_revert_to_mark();
private:
    void pldisplay_aux(std::stringstream& ss, char ch, bool in_list, uint32_t i, uint32_t offset);
    uint32_t* variables=new uint32_t[STACK_SIZES];
    List* list_values=new List[STACK_SIZES];
    uint32_t* unwind_stack_decouple=new uint32_t[STACK_SIZES];
    uint32_t* unwind_stack_decouple_mark=new uint32_t[STACK_SIZES];
    uint32_t top_variables=0;
    uint32_t top_list_values=1; // don't use 0, so that can be freelist stop
    uint32_t top_unwind_stack_decouple=0;
    uint32_t top_unwind_stack_decouple_mark=0;
    uint32_t freelist_list=0;
    uint8_t* stack_storage=new uint8_t[STACK_SIZES];
    FrameStore frames[10];
    uint32_t frame_count=0;
    uint8_t* base_sp=0;
    uint32_t global_stack_storage_index=0;
};
