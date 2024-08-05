        .globl  _ZN6Prolog29process_stack_state_load_saveEP10FrameStore # -- Begin function Prolog::process_stack_state_load_save(FrameStore* fs)
        .p2align 4, 0x90
        .type   _ZN6Prolog29process_stack_state_load_saveEP10FrameStore,@function
_ZN6Prolog29process_stack_state_load_saveEP10FrameStore: # @Prolog::process_stack_state_load_save(FrameStore* fs)
        test   %rsi,%rsi
        je     restore
        mov    %rbx,(%rsi)
        mov    %rsp,0x08(%rsi)
        mov    %rbp,0x10(%rsi)
        mov    %r12,0x18(%rsi)
        mov    %r13,0x20(%rsi)
        mov    %r14,0x28(%rsi)
        mov    %r15,0x30(%rsi)
        mov    %rsi,%rbx
        call    _ZN6Prolog28process_stack_state_save_auxEP10FrameStore
        mov    %rbx,%rax
        mov    (%rbx),%rbx # rbx is callee saved
        ret
restore:
        call   _ZN6Prolog28process_stack_state_load_auxEv
        mov    0x48(%rax),%r8
        test   %r8,%r8
        je     copy_to_stack_noloop
        mov    0x38(%rax),%rdx
        mov    0x40(%rax),%rsi
        xor    %edi,%edi
        .p2align 4, 0x90
copy_to_stack_loop:
        mov    (%rdx,%rdi,8),%rcx
        mov    %rcx,(%rsi,%rdi,8)
        add    $0x1,%edi
        cmp    %edi,%r8d
        jne    copy_to_stack_loop
copy_to_stack_noloop:
        mov    0x30(%rax),%r15
        mov    0x28(%rax),%r14
        mov    0x20(%rax),%r13
        mov    0x18(%rax),%r12
        mov    0x10(%rax),%rbp
        mov    0x08(%rax),%rsp
        mov    (%rax),%rbx
        ret    
