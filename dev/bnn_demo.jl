using Turing



function sigmoid(t)
  return 1 / (1 + e^(-t))
end

function nn(x, b1, w11, w12, w13, bo, wo)
  # wi = weight_in, wh = weight_hidden, wo = weight_out
  h = tanh([w11' * x + b1[1]; w12' * x + b1[2]; w13' * x + b1[3]])
  return sigmoid((wo' * h)[1] + bo)
end

function predict(x, chain)
  n = length(chain[:b1])
  b1 = chain[:b1]
  w11 = chain[:w11]
  w12 = chain[:w12]
  w13 = chain[:w13]
  bo = chain[:bo]
  wo = chain[:wo]
  return mean([nn(x, b1[i], w11[i], w12[i], w13[i], bo[i], wo[i]) for i in 1:n])
end

function hard_predict(x, chain)
  b1 = mean(chain[:b1])
  w11 = mean(chain[:w11])
  w12 = mean(chain[:w12])
  w13 = mean(chain[:w13])
  bo = mean(chain[:bo])
  wo = mean(chain[:wo])
  return nn(x, b1, w11, w12, w13, bo, wo)
end

# xs = Array[[1; 1], [0; 0], [1; 0], [0; 1]]
# ts = [1; 1; 0; 0]
N = 200
M = int64(N / 4)
x1s = rand(M) * 5
x2s = rand(M) * 5
xt1s = Array([[x1s[i]; x2s[i]] for i = 1:M])
append!(xt1s, Array([[x1s[i] - 6; x2s[i] - 6] for i = 1:M]))

xt0s = Array([[x1s[i]; x2s[i] - 6] for i = 1:M])
append!(xt0s, Array([[x1s[i] - 6; x2s[i]] for i = 1:M]))

xs = [xt1s; xt0s]
ts = [ones(M); ones(M); zeros(M); zeros(M)]

alpha = 0.16            # regularizatin term
var = sqrt(1.0 / alpha) # variance of the Gaussian prior
@model bnn begin
  @assume b1 ~ MvNormal([0 ;0; 0], [var 0 0; 0 var 0; 0 0 var])
  @assume w11 ~ MvNormal([0; 0], [var 0; 0 var])
  @assume w12 ~ MvNormal([0; 0], [var 0; 0 var])
  @assume w13 ~ MvNormal([0; 0], [var 0; 0 var])
  @assume bo ~ Normal(0, var)
  @assume wo ~ MvNormal([0; 0; 0], [var 0 0; 0 var 0; 0 0 var])
  for i = rand(1:N, 10)
    y = nn(xs[i], b1, w11, w12, w13, bo, wo)
    @observe ts[i] ~ Bernoulli(y)
  end
  @predict b1 w11 w12 w13 bo wo
end

@time chain = sample(bnn, HMC(3000, 0.1, 5))

[predict(xs[i], chain) for i = 1:N]



using Mamba: Chains, summarystats
s = map(x -> x[1], chain[:wo])
println(summarystats(Chains(s)))



using Gadfly



d1_layer = layer(x=map(e -> e[1], xt1s), y=map(e -> e[2], xt1s), Geom.point, Theme(default_color=colorant"royalblue"))
d2_layer = layer(x=map(e -> e[1], xt0s), y=map(e -> e[2], xt0s), Geom.point, Theme(default_color=colorant"springgreen"))

plot(d1_layer, d2_layer)

p_layer = layer(z=(x,y) -> predict([x, y], chain), x=linspace(-6,6,25), y=linspace(-6,6,25), Geom.contour)

plot(d1_layer, d2_layer,p_layer)
