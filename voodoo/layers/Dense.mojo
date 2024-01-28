from voodoo import Tensor, get_activation_code, shape
from .BaseLayer import BaseLayer


struct Dense[
    in_neurons: Int,
    out_neurons: Int,
    activation: String = "none",
    use_bias: Bool = True,
    weight_initializer: String = "glorot_uniform",
    bias_initializer: String = "zeros",
    weight_mean: Float32 = 0.0,
    weight_std: Float32 = 0.05,
    bias_mean: Float32 = 0.0,
    bias_std: Float32 = 0.05,
](BaseLayer):
    var W: Tensor
    var bias: Tensor

    fn __init__(
        inout self,
    ) raises:
        self.W = Tensor(shape(in_neurons, out_neurons)).initialize[
            weight_initializer, weight_mean, weight_std
        ]()
        self.W = self.W.requires_grad()

        @parameter
        if self.use_bias:
            self.bias = Tensor(shape(out_neurons)).initialize[
                bias_initializer, bias_mean, bias_std
            ]()
            self.bias = self.bias.requires_grad()
        else:
            self.bias = Tensor(shape(out_neurons))

    @always_inline("nodebug")
    fn forward(self, x: Tensor) raises -> Tensor[False, False]:
        var computed = x @ self.W

        @parameter
        if self.use_bias:
            computed = computed + self.bias

        @parameter
        if self.activation != "none":
            return computed.compute_activation[get_activation_code[activation]()]()

        return computed
