start:
  addi s0, x0, 0x100
  addi s1, x0, 5
  addi s2, x0, 0x114

  addi t0, x0, 3
  sw   t0, 0(s0)
  addi t0, x0, 1
  sw   t0, 4(s0)
  addi t0, x0, 4
  sw   t0, 8(s0)
  addi t0, x0, 0
  sw   t0, 12(s0)
  addi t0, x0, 2
  sw   t0, 16(s0)

  sw   x0, 0(s2)
  addi t0, x0, 0

outer_loop:
  addi t2, s1, -1
  bge  t0, t2, sort_done
  addi t1, x0, 0

inner_loop:
  sub  t3, t2, t0
  bge  t1, t3, next_outer
  slli t4, t1, 2
  add  t4, s0, t4
  lw   t5, 0(t4)
  lw   t6, 4(t4)
  bge  t5, t6, no_swap
  sw   t6, 0(t4)
  sw   t5, 4(t4)

no_swap:
  addi t1, t1, 1
  jal  x0, inner_loop

next_outer:
  addi t0, t0, 1
  jal  x0, outer_loop

sort_done:
  addi t0, x0, 1
  sw   t0, 0(s2)

end_loop:
  jal  x0, end_loop
