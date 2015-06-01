function solve_conductance()
% find the fixed points of the conductance model
% reference: Chapter 15 Mean-Field Theory of Irregularly Spiking Neuronal 
% Populations and Working Memory in Recurrent Cortical Networks
% Yifan Gu, 31-May-2015

clc;clear;close all;

% my_fun =  @(v) phi(v) - v;
% v_guess = 2*ones(9,1)/1000; % KHz = 1/ms
% v_guess = 10*rand(9,1)/1000; % KHz = 1/ms
% v_guess = [20; ones(7,1); 20] /1000; % KHz = 1/ms
% v_fixed = fsolve( my_fun, v_guess)


v_guess = [1; ones(7,1); 2] /1000; % KHz = 1/ms
v_guess = zeros(9,1);
v_new = phi(v_guess)

end


function v_new = phi(v)
% phi is the input-output relation

% v cannot be negative
v = abs(v); % this may cause instability in Newtown's method?

% define parameters
V_shift = 70;
Vth = -50 + V_shift; % mV; threshold
Vr = -60 + V_shift; % mV; reset 
V_L = -70 + V_shift;
tau_ref = 2; % ms;
gL = 0.0167; % miuS
Cm = 0.25; %nF

% define network
tau_syn = [5*ones(8,1); 3]; % ms; synaptic decay time constants
tau_syn_avg = 4; % ms; this simplification is made by me; cannot see any other choice
Vrev = [0*ones(8,1); -80] + V_shift; % reversal potential
Iapp = 1.5; % nA
[C, g] = get_C_J();

% get sbar 
sbar = tau_syn .* v;  % this linear approximation could be problematic; consider use emperical results

% get gL_eff
gL_eff = gL + mtimes(C.*g, sbar);
% get tau_m_eff
tau_m_eff = Cm./gL_eff;

% get Vss
Vss = (gL*V_L + mtimes(C.*g, sbar.*Vrev) + Iapp)./gL_eff; % double check the matrix & vector operations

% get Vbar
Vbar = Vss - (Vth-Vr).*tau_m_eff.*v - (Vss-Vr).*tau_ref.*v; % (15.52) ?

% get sigma_c_eff
sigma_C_eff = (  mtimes(C.*(g.^2),  sbar.*tau_syn.*((Vbar - Vrev).^2))  ).^0.5; % double check the matrix & vector operations

% get sigma_V_eff
sigma_V_eff = sigma_C_eff./((tau_m_eff.^0.5).*gL_eff); % I added this equation because I believe there is a mistake in (15.62)

% get V_th_eff & V_r_eff
alpha = 1.03;
k = (tau_syn_avg ./ tau_m_eff).^0.5; % this is my own approximation, which can be problematic; 
% This first order correction is in good agreement with the results from
% numerical simulations for tau_syn < 0.1*tau_m
Vth_eff = Vth + sigma_V_eff .* alpha .* k;
Vr_eff = Vr + sigma_V_eff .* alpha .* k;

% get upper & lower limits of the integral
upper = (Vth_eff - Vss)./sigma_V_eff;
lower = (Vr_eff - Vss)./sigma_V_eff;
if sum( upper <= lower ) > 0
    upper, lower
    pause;
end

% calculate firing rate 
v_new = zeros(size(v));
fx = @(x) exp(x.^2).*(1+erf(x));
for i = 1:length(v);
    v_new(i) = 1/(tau_ref + tau_m_eff(i)*sqrt(pi)*integral(fx, lower(i), upper(i))); % can matlab integral() be counted on?!
end



end



function [C, J] = get_C_J()

% get C
lesion_1 = 1.1;
lesion_2 = 1;
lesion_3 = 1;
lesion_4 = 0.6;
rr = 0.7;
P0 = 0.2;
[P, CL] = inter_module_Pmatrix(500*ones(8, 1), P0, rr);
P(CL==1) = P(CL==1)*lesion_1;
P(CL==2) = P(CL==2)*lesion_2;
P(CL==3) = P(CL==3)*lesion_3;
P(CL==4) = P(CL==4)*lesion_4;
P_tot = 0.5*ones(9,9);
P_tot(1:8,1:8) = P;
N = [500*ones(1,8) 1000];
C = zeros(9,9);
for i = 1:9
    C(i,:) = P_tot(i,:).*N;
end

% get J
kk = 1; %2:5; % use 2 to roughly compensate synaptic saturation
EE_factor = 0.6;
II_factor = 0.8;
Kmat = [2.4*EE_factor  1.4;
        4.5  5.7*II_factor]*kk*10^-3; % miuSiemens
J = zeros(9,9);
J(1:8,1:8) = Kmat(1,1);
J(9,1:8) = Kmat(2,1);
J(1:8,9) = Kmat(1,2);
J(9,9) = Kmat(2,2);
    
end







