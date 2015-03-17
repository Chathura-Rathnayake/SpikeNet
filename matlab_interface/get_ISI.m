function [R] = get_ISI(R)
% dump fields
dt = R.dt;
N = R.N;
Num_pop = R.Num_pop;
num_spikes = R.num_spikes;
spike_hist = R.spike_hist;

%
fprintf('\t Getting ISI distribution...\n');
ISI_lumped = cell(Num_pop,1); % ISI histogram
ISI_lumped_ind = cell(Num_pop,1); % neuron index
for pop_ind = 1:Num_pop
    if nnz(num_spikes{pop_ind}) > 0
        for i = 1:N(pop_ind)

            spike_temp = find(spike_hist{pop_ind}(i,:)); % in time step in lieu of ms!!!
            
            if length(spike_temp) >= 2
                
                Dt_temp = (spike_temp(2:end)-spike_temp(1:end-1))*dt; % in ms
                ISI_lumped{pop_ind} = [ISI_lumped{pop_ind} Dt_temp];
                ISI_lumped_ind{pop_ind} = [ISI_lumped_ind{pop_ind} i*ones(size(Dt_temp)) ];
            end
        end
    end
end
% record results
R.Analysis.ISI_lumped = ISI_lumped;
R.Analysis.ISI_lumped_ind = ISI_lumped_ind;

end