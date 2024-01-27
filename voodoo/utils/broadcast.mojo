from math import max
from voodoo import Node


@always_inline
fn shape_a(depth: Int, a: Node, b: Node) -> Int:
    let diff = max(b.num_dims - a.num_dims, 0)
    if depth < diff:
        return 1
    return a.shape.load(depth - diff)


@always_inline
fn shape_b(depth: Int, a: Node, b: Node) -> Int:
    let diff = max(a.num_dims - b.num_dims, 0)
    if depth < diff:
        return 1
    return b.shape.load(depth - diff)


@always_inline
fn strides_a(depth: Int, a: Node, b: Node) -> Int:
    let diff = max(b.num_dims - a.num_dims, 0)
    if depth < diff:
        return a.strides.load(0)
    return a.strides.load(depth - diff)


@always_inline
fn strides_b(depth: Int, a: Node, b: Node) -> Int:
    let diff = max(a.num_dims - b.num_dims, 0)
    if depth < diff:
        return b.strides.load(0)
    return b.strides.load(depth - diff)


fn recursive_broadcast[
    kernel: fn (
        c: Node, a: Node, b: Node, a_index: Int, b_index: Int, c_index: Int, depth: Int
    ) capturing -> None,
    base_case: fn (depth: Int, a: Node, b: Node) capturing -> Bool,
](
    c: Node,
    a: Node,
    b: Node,
    a_index: Int = 0,
    b_index: Int = 0,
    c_index: Int = 0,
    depth: Int = 0,
):
    if base_case(depth, a, b):
        kernel(c, a, b, a_index, b_index, c_index, depth)
        return

    let a_shape = shape_a(depth, a, b)
    let b_shape = shape_b(depth, a, b)
    let c_shape = c.shape.load(depth)

    let a_ishape = a_shape * a_index
    let b_ishape = b_shape * b_index
    let c_ishape = c_shape * c_index

    if a_shape != 1 and b_shape == 1:
        for s in range(a_shape):
            recursive_broadcast[kernel, base_case](
                c,
                a,
                b,
                a_ishape + s,
                b_index,
                c_ishape + s,
                depth + 1,
            )
    elif a_shape == 1 and b_shape != 1:
        for s in range(b_shape):
            recursive_broadcast[kernel, base_case](
                c,
                a,
                b,
                a_index,
                b_ishape + s,
                c_ishape + s,
                depth + 1,
            )
    else:
        for s in range(a_shape):
            recursive_broadcast[kernel, base_case](
                c,
                a,
                b,
                a_ishape + s,
                b_ishape + s,
                c_ishape + s,
                depth + 1,
            )


fn recursive_broadcast_bw[
    kernel: fn (
        c: Node, a: Node, b: Node, a_index: Int, b_index: Int, c_index: Int, depth: Int
    ) capturing -> None,
    base_case: fn (depth: Int, a: Node, b: Node) capturing -> Bool,
](
    c: Node,
    a: Node,
    b: Node,
    a_index: Int = 0,
    b_index: Int = 0,
    c_index: Int = 0,
    depth: Int = 0,
):
    if base_case(depth, a, b):
        kernel(c, a, b, a_index, b_index, c_index, depth)
        return

    let a_shape = shape_a(depth, a, b)
    let b_shape = shape_b(depth, a, b)
    let c_shape = c.shape.load(depth)

    let a_ishape = a_shape * a_index
    let b_ishape = b_shape * b_index
    let c_ishape = c_shape * c_index

    if a_shape != 1 and b_shape == 1:
        for s in range(a_shape):
            recursive_broadcast_bw[kernel, base_case](
                c,
                a,
                b,
                a_ishape + s,
                b_index,
                c_ishape + s,
                depth + 1,
            )
    elif a_shape == 1 and b_shape != 1:
        for s in range(b_shape):
            recursive_broadcast_bw[kernel, base_case](
                c,
                a,
                b,
                a_index,
                b_ishape + s,
                c_ishape + s,
                depth + 1,
            )
    else:
        for s in range(a_shape):
            recursive_broadcast_bw[kernel, base_case](
                c,
                a,
                b,
                a_ishape + s,
                b_ishape + s,
                c_ishape + s,
                depth + 1,
            )
