function main_16clusters(varargin)
% use sparse connection: in degree and out degree does not scale with
% network size
% The strategy here is to keep the synaptic strength but scale down the inter-modular
% wiring probability. 
%
% Another way is to scale down the synaptic strength but let the wiring
% probability scale with the network size.


% varargin is for PBS arrary job
if nargin == 0
    clc;clear all;close all;
    cd /import/yossarian1/yifan/Project1/
    addpath(genpath(cd));
    cd tmp_data
end % Basic parameters
N = [4000; 1000]*2; %!!!
dt = 0.1;
sec = round(10^3/dt); % 1*(10^3/dt) = 1 sec
step_tot = 10*sec;

% Loop number for PBS array job
% Num_pop = length(N);
loop_num = 0;
discard_transient = 500; % ms

EE_factor = 0.6; %0.4:0.1:0.6;
II_factor = 0.8; %0.7:0.1:0.9;


Pmat = [0.2 0.5;
        0.5 0.5];


%%%%%%%% Hierarchical Connection and Lesion%%%%%%%%%%%%%%%%%
rr = 0.6;
P0 = Pmat(1,1);
Msize = Mnum_2_Msize(8, 4000);
[P, CL] = inter_module_Pmatrix(Msize, P0, rr);

% Do lesion here
for lesion_1 = 1      %+(-0.05:0.05:0.05) %1.1:0.1:1.4 % range [0-1]
    for lesion_2 = 1    %+(-0.05:0.05:0.05)
        for lesion_3 = 1    %+(-0.05:0.05:0.05)
            for lesion_4 = 0.5  %+(-0.05:0.05:0.05)
                P(CL==4) = P(CL==4)*lesion_4; % highest level connection
                P(CL==3) = P(CL==3)*lesion_3;  %*lesion_left;  % second-highest level connection
                P(CL==2) = P(CL==2)*lesion_2; % third-highest level connection
                P(CL==1) = P(CL==1)*lesion_1;
            end
        end
    end
end




for lesion_5 = 0.6:0.1:1
    
    %
    P4 = unique(P(CL==4));
    P5 = ones(size(P))*P4(1)*rr*lesion_5;
    
    P = [P  P5;
         P5 P ];
    
    
    % Generate full connection matrix from P
    Mnum = 16; %!!!
    Msize = Mnum_2_Msize(Mnum, 8000);
    A11 = P_2_A(P,Msize);
    
    
    
    
    TYPEmat = [1 2];
    
    
    
    for kk = 0.8:0.05:1; %2:5; % use 2 to roughly compensate synaptic saturation
        
        Kmat = [2.4*EE_factor  1.4;
            4.5  5.7*II_factor]*kk*10^-3; % miuSiemens
        
        for rate_ext = 4.4*ones(1,1) %linspace(4.0,4.0,45) %4.0:0.025:4.5 %4.1:0.025:4.5; % Hz
            
            loop_num = loop_num + 1;
            
            % For PBS array job
            if nargin ~= 0
                PBS_ARRAYID = varargin{1};
                if loop_num ~=  PBS_ARRAYID
                    continue;
                end
            end
            
            % seed the matlab rand function! The seed is global.
            % Be very careful about that!!!!!!!!!!!
            rand_seed = loop_num*10^5+eval(datestr(now,'SSFFF'));
            rng(rand_seed,'twister');
            
            % Creat ygin file
            % using loop_num in filename to ensure unique naming!
            % Otherwise overwriting may occur when using PBS.
            name = [ sprintf('%03g-', loop_num), datestr(now,'yyyymmddHHMM-SSFFF')];
            
            fprintf('Data file name is: \n%s\n', strcat(name,'.ygin') ); % write the file name to stdout and use "grep ygin" to extract it
            FID = fopen([name,'.ygin'], 'w'); % creat file
            FID_syn = fopen([name,'.ygin_syn'], 'w'); % creat file
            
            % write basic parameters
            writeBasicPara(FID, dt, step_tot, N)
            % write pop para
            writePopPara(FID, 1,  'tau_ref', 2);
            writePopPara(FID, 2,  'tau_ref', 2);
            % write synapse para
            writeSynPara(FID, 'tau_decay_GABA', 3);
            
            %%%%%%% write runaway killer
            runaway_steps = round(50/dt);
            runaway_mean_num_ref = 0.4;
            writeRunawayKiller(FID, runaway_steps, runaway_mean_num_ref);
            %%%%%%%%%%%%%%%%%%%%%%%%
            
            
            
            
            %%%%%%% external spikes settings (FID, pop_ind, type_ext, K_ext, Num_ext, rate_ext)
            Num_ext = 400;
            K_ext = Kmat(1,1);
            rate_t = zeros(1,step_tot);
            
            rate_t(:) = rate_ext;
            
            
            writeExtSpikeSettings(FID, 1, 1, K_ext,  Num_ext, rate_t, 1, N(1));
            writeExtSpikeSettings(FID, 2, 1, K_ext,  Num_ext, rate_t, 1, N(2));
            % writeExtSpikeSettings(FID, 3, 1, K_ext,  Num_ext, rate_ext);
            
            %%%%%%% data sampling
            writeNeuronSampling(FID, 1, [1,1,1,1,0,0,1],[100:500:4000]);
            writeNeuronSampling(FID, 2, [1,1,1,1,0,0,1],[100;600]);
            %                                         pop_V_t_index = zeros(1,step_tot);
            %                                         pop_V_t_index(1:sec:step_tot) = 1;
            %                                         writePopSampling(FID,1,pop_V_t_index);
            
            
            %     %%%%%%% random initial condition settings (int pop_ind, double p_fire)
            %     p_fire = -0.2*ones(size(N)); % between [0,1], 0.05
            %     writeInitV(FID, p_fire);
            
            %%%%%%%%%%%%%%%%%%% Chemical Connections %%%%%%%%%%%%%%%%%%%%%%%
            % type(1:AMAP, 2:GABAa, 3:NMDA)
            
            %
            for i_pre = 1:2
                for j_post = 1:2
                    
                    if i_pre == 1 && j_post == 1
                        % hierarchical structure
                        
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        [I, J, ~] = find(A11);
                        % % save A11
                        % save([name,'A11.mat'], 'A11');
                    else
                        P_tmp =  Pmat(i_pre,j_post)/2; %!!!!!!
                        [I, J, ~] = find(MyRandomGraphGenerator('E_R_pre_post','N_pre',N(i_pre),'N_post',N(j_post),'p',P_tmp));
                    end
                    
                    
                    K = ones(size(I))*Kmat(i_pre,j_post);
                    
                    
                    
                    D = rand(size(I))*1;
                    writeChemicalConnection(FID_syn, TYPEmat(i_pre),  i_pre,j_post,   I,J,K,D); % (FID, type, i_pre, j_post, I, J, K, D)
                    clear I J K D;
                end
            end
            
            
            
            % Explanatory (ExplVar) and response variables (RespVar) for cross-simulation data gathering and post-processing
            % Record explanatory variables, also called "controlled variables"
            
            writeExplVar(FID, 'discard_transient', discard_transient, ...
                'loop_num', loop_num, ...
                'rate_ext', rate_ext, ...
                'k', kk, ...
                'Mnum', Mnum, ...
                'lesion_5', lesion_5, 'lesion_4',lesion_4,'lesion_3',lesion_3,'lesion_2',lesion_2,'lesion_1',lesion_1);
            
            
            
            % Adding comments in raster plot
            comment1 = 'p=[0.2 0.5 0.5 0.5], k = [2.4*EE_fatcor 1.4;4.5 5.7*II_factor]*k*10^-3, tau_decay_GABA=3';
            comment2 = datestr(now,'dd-mmm-yyyy-HH:MM');
            writeExplVar(FID, 'comment1', comment1, 'comment2', comment2);
            
            
            % append this file self into .ygin for future reference
            appendThisMatlabFile(FID)
            
        end
        
    end
    
end
end



% This function must be here!
function appendThisMatlabFile(FID)
breaker = repmat('#',1,80);
fprintf(FID, '%s\n', breaker);
fprintf(FID, '%s\n', '# MATLAB script generating this file: ');
fprintf(FID, '%s\n', breaker);
Fself = fopen([mfilename('fullpath'),'.m'],'r');
while ~feof(Fself)
    tline = fgetl(Fself);
    fprintf(FID, '%s\n', tline);
end
fprintf(FID, '%s\n', breaker);
fprintf(FID, '%s\n', breaker);
fprintf(FID, '%s\n', breaker);
end