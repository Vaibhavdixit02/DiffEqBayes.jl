using DiffEqBayes, OrdinaryDiffEq, ParameterizedFunctions, RecursiveArrayTools
using DynamicHMC, DiffWrappers, ContinuousTransformations
using Parameters, Distributions, Optim

f1 = @ode_def_nohes LotkaVolterraTest1 begin
  dx = a*x - x*y
  dy = -3*y + x*y
end a
p = [1.5]
u0 = [1.0,1.0]
tspan = (0.0,10.0)
prob1 = ODEProblem(f1,u0,tspan,p)

σ = 0.01                         # noise, fixed for now
t = collect(range(1, stop=10, length=10))   # observation times
sol = solve(prob1,Tsit5())
randomized = VectorOfArray([(sol(t[i]) + σ * randn(2)) for i in 1:length(t)])
data = convert(Array,randomized)

bayesian_result = dynamichmc_inference(prob1, Tsit5(), t, data, [Normal(1.5, 1)], [bridge(ℝ, ℝ⁺, )])
@test mean(bayesian_result[1][1]) ≈ 1.5 atol=1e-1

# With hand-code likelihood function
weights_ = ones(data) # weighted data
for i = 1:3:length(data)
    weights_[i] = 0
    data[i] = 1e20 # to test that those points are indeed not used
end
likelihood = function (sol)
    l = 0.0
    for (i, t) in enumerate(t)
        l += sum(logpdf.(Normal(0.0, σ), sol(t) - data[:, i]) .* weights_[:,i])
    end
    return l
end
bayesian_result = dynamichmc_inference(prob1, Tsit5(), likelihood, [Truncated(Normal(1.5, 1), 0, 2)], [bridge(ℝ, ℝ⁺, )])
@test mean(bayesian_result[1][1]) ≈ 1.5 atol=1e-1


f1 = @ode_def_nohes LotkaVolterraTest4 begin
  dx = a*x - b*x*y
  dy = -c*y + d*x*y
end a b c d
u0 = [1.0,1.0]
tspan = (0.0,10.0)
p = [1.5,1.0,3.0,1.0]
prob1 = ODEProblem(f1,u0,tspan,p)
sol = solve(prob1,Tsit5())
t = collect(range(1, stop=10, length=10))
randomized = VectorOfArray([(sol(t[i]) + .01randn(2)) for i in 1:length(t)])
data = convert(Array,randomized)
priors = [Truncated(Normal(1.5,0.01),0,2),Truncated(Normal(1.0,0.01),0,1.5),
          Truncated(Normal(3.0,0.01),0,4),Truncated(Normal(1.0,0.01),0,2)]

bayesian_result = dynamichmc_inference(prob1, Tsit5(), t, data, priors, [bridge(ℝ, ℝ⁺, ),bridge(ℝ, ℝ⁺, ),bridge(ℝ, ℝ, ),bridge(ℝ, ℝ⁺, )])
@test mean(bayesian_result[1][1]) ≈ 1.5 atol=1e-1
@test mean(bayesian_result[1][2]) ≈ 1.0 atol=1e-1
@test mean(bayesian_result[1][3]) ≈ 3.0 atol=1e-1
@test mean(bayesian_result[1][4]) ≈ 1.0 atol=1e-1
