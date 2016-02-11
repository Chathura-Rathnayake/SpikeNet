function [ R ] = get_grid_firing_centre( R )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here



% parameters
win_len = 200; % window length in time steps
win_gap = 100; % window gap
win_min_rate_Hz = 0.5;


spikes_win_min = win_min_rate_Hz*(R.dt*0.001)*win_len*R.N(1);

[ t_mid, ind_ab,  num_spikes_win ] = window_spike_hist_compressed( R, win_len, win_gap );
ind_a_vec = ind_ab(1,:);
ind_b_vec = ind_ab(2,:);


%%%% get window-ed mean and std for x/y position of firing neurons
hw = (R.N(1)^0.5 - 1)/2;
fw = 2*hw+1;

if mod(hw, 1) ~= 0
    warning('Not a square grid')
else
    
    [Lattice, ~] = lattice_nD(2, hw);
    
    x_pos_o = Lattice(R.spike_hist_compressed{1}, 1);
    y_pos_o = Lattice(R.spike_hist_compressed{1}, 2);
    
    x_shift = [0 hw hw  -hw -hw];
    y_shift = [0 hw -hw  hw -hw];
    
    x_mean_all = [];
    y_mean_all = [];
    dist_std_all = [];
    
    for i = 1:length(x_shift)
        
        % shift grid centre
        x_pos =  mod(x_pos_o - x_shift(i)+hw, fw) - hw;
        y_pos =  mod(y_pos_o - y_shift(i)+hw, fw) - hw;
        % minmax( [x_pos', y_pos'])
        
        x_mean = [];
        y_mean = [];
        dist_std = [];
        
        for j = 1:length(ind_a_vec)
            ind_range_tmp = ind_a_vec(j):ind_b_vec(j);
            x_pos_tmp = x_pos(ind_range_tmp);
            y_pos_tmp = y_pos(ind_range_tmp);
            
            x_mean = [x_mean mean(x_pos_tmp ) ]; %#ok<AGROW>
            y_mean = [y_mean mean(y_pos_tmp) ]; %#ok<AGROW>
            dist_std = [dist_std (std(x_pos_tmp).^2 + std(y_pos_tmp).^2).^0.5 ]; %#ok<AGROW>
            
            % if there is no spike in the current window, NaN will be
            % returned
        end
        x_mean_all = [x_mean_all; x_mean];%#ok<AGROW>
        y_mean_all = [y_mean_all; y_mean];%#ok<AGROW>
        dist_std_all = [dist_std_all;  dist_std];%#ok<AGROW>
        
    end

    %%%%%%%%%%%%% now find the right shifting
    
    [dist_std_min, dist_std_min_ind] = min(dist_std_all);
    dist_std_min_mean = mean(dist_std_min(~isnan(dist_std_min)));
    dist_std_min_std = std(dist_std_min(~isnan(dist_std_min)));
    
    xy_mean_ind_chosen = (dist_std_min < dist_std_min_mean - dist_std_min_std) & (num_spikes_win >= spikes_win_min );
    
    x_mean_chosen = [];
    y_mean_chosen = [];
    for i = 1:length(xy_mean_ind_chosen)
        if xy_mean_ind_chosen(i)
            
            % shift the position back to normal
            x_mean_tmp = x_mean_all(dist_std_min_ind(i), i) + x_shift(dist_std_min_ind(i));
            y_mean_tmp = y_mean_all(dist_std_min_ind(i), i) + y_shift(dist_std_min_ind(i));
            x_mean_tmp = (mod(x_mean_tmp+hw, fw) - hw); 
            x_mean_tmp =  x_mean_tmp - 2*hw*(x_mean_tmp > 31);% a hack????
            y_mean_tmp = (mod(y_mean_tmp+hw, fw) - hw);
            y_mean_tmp =  y_mean_tmp - 2*hw*(y_mean_tmp > 31);
            
            x_mean_chosen = [x_mean_chosen x_mean_tmp];%#ok<AGROW>
            y_mean_chosen = [y_mean_chosen y_mean_tmp];%#ok<AGROW>
        end
    end

    t_mid_chosen = t_mid(xy_mean_ind_chosen);
    dist_std_chosen = dist_std_min(xy_mean_ind_chosen);
    
    % jump_size (take care of the periodic boundary condition)
    x_diff_full = repmat(x_mean_chosen(2:end), 9, 1);
    y_diff_full = repmat(y_mean_chosen(2:end), 9, 1);
    x_mean_shift2 = [-fw 0  fw -fw 0 fw -fw  0   fw];
    y_mean_shift2 = [ fw fw fw   0 0  0 -fw -fw -fw];
    for s = 1:9
        x_diff_full(s,:) =  x_diff_full(s,:) - x_mean_shift2(s) - x_mean_chosen(1:end-1);
        y_diff_full(s,:) =  y_diff_full(s,:) - y_mean_shift2(s) - y_mean_chosen(1:end-1) ;
    end
    jump_dist = min(sqrt(x_diff_full.^2 + y_diff_full.^2));
    % jump_duration
    jump_duration = diff(t_mid_chosen);
    
    % output results
    R.grid.t_mid_full = t_mid;
    R.grid.t_mid = t_mid_chosen;
    R.grid.radius = dist_std_chosen;
    R.grid.centre = [x_mean_chosen; y_mean_chosen];
    R.grid.jump_dist = jump_dist;
    R.grid.jump_du = jump_duration;
    R.grid.hw = hw;
    R.grid.win_len = win_len;
    R.grid.win_gap = win_gap; % window gap
    R.grid.win_min_rate_Hz = win_min_rate_Hz;
    R.grid.ind_ab = ind_ab;
    R.grid.num_spikes_win = num_spikes_win;
end


% % % Code for visualization
% figure('Name','Vis','color','w','NumberTitle','off');
% 
% axis equal;
% box on;
% set(gca,'xtick',[],'ytick',[]);
% 
% xlim([-hw hw]);
% ylim([-hw hw]);
% hold on;
% 
% j = 1;
% 
% ang=0:0.01:2*pi;
% x_shift_vs = [0 fw fw -fw -fw fw -fw 0 0 ];
% y_shift_vs = [0 fw -fw fw -fw 0  0   fw -fw];
% 
% for t = 1:length(t_mid);
%     h2 = plot(100,0);
%     h3 = plot(100,0);
%     
%     ind_range_tmp = ind_a_vec(t):ind_b_vec(t);
%     h1 = plot(x_pos_o(ind_range_tmp), y_pos_o(ind_range_tmp), 'bo');
%     if sum(t_mid_chosen == t_mid(t)) == 1
%         
%         x_tmp = x_mean_chosen(j);
%         y_tmp = y_mean_chosen(j);
%         r_cos = x_tmp+dist_std_chosen(j)*cos(ang);
%         r_sin = y_tmp+dist_std_chosen(j)*sin(ang);
%         
%         
%         
%         h3 = plot(r_cos - x_shift_vs(1),r_sin - y_shift_vs(1),'r', ...
%             r_cos - x_shift_vs(2),r_sin - y_shift_vs(2),'r',...
%             r_cos - x_shift_vs(3),r_sin - y_shift_vs(3),'r',...
%             r_cos - x_shift_vs(4),r_sin - y_shift_vs(4),'r',...
%             r_cos - x_shift_vs(5),r_sin - y_shift_vs(5),'r', ...
%             r_cos - x_shift_vs(6),r_sin - y_shift_vs(6),'r', ...
%             r_cos - x_shift_vs(7),r_sin - y_shift_vs(7),'r', ...
%             r_cos - x_shift_vs(8),r_sin - y_shift_vs(8),'r', ...
%             r_cos - x_shift_vs(9),r_sin - y_shift_vs(9),'r');
%         
%         if j == 1
%             h2 = plot( x_tmp, y_tmp, 'r>', 'MarkerSize', 8);
%         else
%             %h2 = plot( [x_mean_chosen(j-1) x_tmp], [y_mean_chosen(j-1) y_tmp], 'r>-', 'MarkerSize',8);
%             h2 = plot( x_tmp, y_tmp, 'rx', 'MarkerSize', 16);
%             xs = sprintf('jump_size = %4.2f', jump_length(j-1));
%             xlabel(xs);
%             %             if jump_length(j-1) > 0
%             %                 clc
%             %                 xy1 = [x_mean_chosen(j-1) y_mean_chosen(j-1)]
%             %                 xy2 = [x_tmp, y_tmp]
%             %                 pause
%             %             end
%         end
%         
%         
%         j = j + 1;
%     end
%     pause(0.02);
%     delete(h1);
%     delete(h2);
%     delete(h3);
%     ts = sprintf('time = %8.1f ms', t*0.1);
%     title(ts);


end

