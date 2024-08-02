        .globl  _ZN6Prolog29process_stack_state_load_saveEP10FrameStore # -- Begin function Prolog::process_stack_state_load_save(FrameStore* fs)
        .p2align 4, 0x90
        .type   _ZN6Prolog29process_stack_state_load_saveEP10FrameStore,@function
_ZN6Prolog29process_stack_state_load_saveEP10FrameStore: # @Prolog::process_stack_state_load_save(FrameStore* fs)
        test   %rsi,%rsi
        je     restore
        mov    %rcx,(%rsi)
        mov    %rdx,0x8(%rsi)
        mov    %rbx,0x10(%rsi)
        mov    %rsp,0x18(%rsi)
        mov    %rbp,0x20(%rsi)
        mov    %rsi,0x28(%rsi)
        mov    %rdi,0x30(%rsi)
        mov    %r8,0x38(%rsi)
        mov    %r9,0x40(%rsi)
        mov    %r12,0x48(%rsi)
        mov    %r13,0x50(%rsi)
        mov    %r14,0x58(%rsi)
        mov    %r15,0x60(%rsi)
        mov    %rsi,%rbx
        call    _ZN6Prolog28process_stack_state_save_auxEP10FrameStore
        mov    %rbx,%rax
        ret
restore:
        call   _ZN6Prolog28process_stack_state_load_auxEv
        movzbl 0x98(%rax),%r8d
        test   %r8,%r8
        je     copy_to_stack_noloop
        mov    0x88(%rax),%rdx
        mov    0x90(%rax),%rsi
        xor    %edi,%edi
        .p2align 4, 0x90
copy_to_stack_loop:
        mov    (%rdx,%rdi,8),%rcx
        mov    %rcx,(%rsi,%rdi,8)
        add    $0x1,%edi
        cmp    %edi,%r8d
        jne    copy_to_stack_loop
copy_to_stack_noloop:
        mov    0x60(%rax),%r15
        mov    0x58(%rax),%r14
        mov    0x50(%rax),%r13
        mov    0x48(%rax),%r12
        mov    0x40(%rax),%r9
        mov    0x38(%rax),%r8
        mov    0x30(%rax),%rdi
        mov    0x28(%rax),%rsi
        mov    0x20(%rax),%rbp
        mov    0x18(%rax),%rsp
        mov    0x10(%rax),%rbx
        mov    0x8(%rax),%rdx
        mov    (%rax),%rcx
        ret    
