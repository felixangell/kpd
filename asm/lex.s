.data
t0:
    .asciz "lexing from pos: %d\n"

.text
__9x64_tests_5start_pS8position_u64:
    pushq %rbp
    movq %rsp, %rbp

    subq $16, %rsp
    
    movq %rdi, %r10
    movq 0(%r10), %rax
    movq %rax, 8(%rsp)
    
    leaq t0(%rip), %rdi
    movq $0, %r14
    movq 8(%rsp, %r14, 8), %rsi
    movb $0, %al
    call printf
    
    addq $16, %rsp
    popq %rbp
    ret

.global main
main:
    pushq %rbp
    movq %rsp, %rbp
    
    subq $16, %rsp
    
    movq $0, %r14
    movq $10, %rax
    movq %rax, 0(%rsp, %r14, 8)
    leaq 0(%rsp), %r10
    
    movq %r10, %rax
    movq %rax, 8(%rsp)
    leaq 8(%rsp), %rdi
    
    movb $0, %al
    call __9x64_tests_5start_pS8position_u64
    
    addq $16, %rsp
    popq %rbp
    ret
