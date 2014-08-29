#include <iostream>
#include <cmath> // always cmath instead of math.h ?
#include <algorithm>
#include <sstream>
#include <fstream>

#include "ChemicalSynapses.h"

ChemicalSynapses::ChemicalSynapses(double dt_input, int step_tot_input){
	
	dt = dt_input;
	step_tot = step_tot_input;
	
	// Default parameters
	V_ex = 0.0;     // Excitatory reversal, 0.0
	V_in = -80.0;   // Inhibitory reversal, -80.0

	//  time-evolution of post-synaptic conductance change (msec)
	Dt_trans_AMPA = 1.0; // 0.5
	Dt_trans_GABA = 1.0; // 1.0
	Dt_trans_NMDA = 5.0; // 5.0
	tau_decay_AMPA = 5.0; // 3.0
	tau_decay_GABA = 3.0; // 7.0
	tau_decay_NMDA = 80.0; // 80.0
}



void ChemicalSynapses::init(int synapses_type_input, int i_pre, int j_post, int N_pre_input, int N_post_input, vector<int> &C_i, vector<int> &C_j, vector<double> &K_ij, vector<double> &D_ij){

	// read parameter
	synapses_type = synapses_type_input;
	pop_ind_pre = i_pre;
	pop_ind_post = j_post;
	N_pre = N_pre_input;
	N_post = N_post_input;
	double max_delay = *max_element(D_ij.begin(), D_ij.end()); // max_element returns an iterator 
	max_delay_steps = int(round(max_delay / dt));
	
	// read in C, K, D
	// Initialise s_TALS, s_VALS
	int i_temp, j_temp;
	for (unsigned int ind = 0; ind < K_ij.size(); ++ind){
		if (K_ij[ind] >= 0.0){ // must be no less than zero! unit: miuSiemens
			if (K.empty()){ // If empty, initialise them
				C.resize(N_pre);
				K.resize(N_pre);
				D.resize(N_pre);
				s_TALS.resize(N_pre);
				s_full.resize(N_pre);
			}
			i_temp = C_i[ind];
			j_temp = C_j[ind];
			C[i_temp].push_back(j_temp);
			K[i_temp].push_back(K_ij[ind]);
			
			D[i_temp].push_back((int)round(D_ij[ind] / dt)); // note that D_ij is in msec
			s_TALS[i_temp].push_back(-1); // -1 for no spike
			s_full[i_temp].push_back(0); // [0,1], portion of open channels, initially all close
		}
		// discard all the zeros
		else{ continue; }
	}

	// parameter-dependent initialisation
	init();

}


void ChemicalSynapses::init(int synapses_type_input, int j_post, int N_post_input, double K_ext_input, int Num_ext_input, vector<double> &rate_ext_t_input){

	// Initialise chemical synapses for simulating external neuron population
	synapses_type = synapses_type_input;
	pop_ind_pre = -1; // -1 for external noisy population
	pop_ind_post = j_post;
	N_post = N_post_input;
	max_delay_steps = 0; // no delay;

	// Parameters for noise generation
	K_ext = K_ext_input;
	Num_ext = Num_ext_input;
	rate_ext_t = rate_ext_t_input;	

	// Random seed (random engine should be feed with DIFFERENT seed at every implementation)
	random_device rd; // random number from operating system for seed
	my_seed = rd(); // record seed
	//my_seed = 321;
	//cout << "My_seed is: " << my_seed << endl;



	// parameter-dependent initialisation
	init();
}



void ChemicalSynapses::init(){
	// parameter-dependent initialisation

	// gs_sum and I
	gs_sum.assign(N_post, 0);
	I.assign(N_post, 0);
	
	// Initialise chemical synapse parameters
	if (synapses_type == 0){
		tau_decay = tau_decay_AMPA;
		steps_trans = int(round(Dt_trans_AMPA / dt));
	}
	else if (synapses_type == 1){	
		tau_decay = tau_decay_GABA;
		steps_trans = int(round(Dt_trans_GABA / dt));
	}
	else if (synapses_type == 2){
		tau_decay = tau_decay_NMDA;
		steps_trans = int(round(Dt_trans_NMDA / dt));
		// non-linearity of NMDA
		// voltage-dependent part B(V) (look-up table):
		miuMg_NMDA = 0.33; // mM^-1, concentration of [Mg2+] is around 1 mM, 0.33
		gamma_NMDA = 0.06; // mV^-1, 0.06
		B_V_min = -80.0 - 1.0; // < V_in = -80, check if they are consistent!!
		B_V_max = -55.0 + 1.0; // > V_th = -55
		B_dV = 0.1; // 0.1
		int i_B = 0;
		double V_temp, B_temp;
		while (true){
			V_temp = B_V_min + i_B*B_dV;
			if (V_temp > B_V_max){ break; }
			B_temp = 1 / (1 + miuMg_NMDA*exp(-gamma_NMDA*V_temp));
			B.push_back(B_temp);
			i_B += 1;
		}
	}

	
	// transmitter_strength
	K_trans =  1.0 / steps_trans; // be careful! 1 / transmitter steps gives zero (int)!!

	// Initialise exp_step
	exp_step = exp(-dt / tau_decay); // single step
	for (int t = 0; t < step_tot; ++t){ // multi-step look-up table
		if (t == 0){ exp_step_table.push_back(1); }
		else {
			exp_step_table.push_back(exp_step_table[t - 1] * exp_step);
		}
	}


	// Initialise pre-synaptic population spike recording
	history_steps = steps_trans + max_delay_steps;// history steps

	if (pop_ind_pre >= 0){
		// spike_pop[time][ind_pre]
		spikes_pop.resize(history_steps); 
		for (int t = 0; t < history_steps; ++t){ 
			spikes_pop[t].reserve(N_pre); 
			// reserve() sets the capacity, note that clear() only affects the size, not the capacity
		}
	}
	else if (pop_ind_pre == -1){
		// gs_buffer[time][ind_post]
		gs_buffer.resize(history_steps); 
		for (int t = 0; t < history_steps; ++t){ 
			gs_buffer[t].reserve(N_post); 
			// reserve() sets the capacity, note that clear() only affects the size, not the capacity
		}
	}
}


void ChemicalSynapses::update(int step_current){

	// Update gs_sum
	if (pop_ind_pre >= 0){
		int t_ring, i_pre, j_post, left_dt_eff; // temporay viarables
		int t_start = (int)fmax(step_current - steps_trans - max_delay_steps, 0); // very beginning of the relevant spike history
		double ds_this_syn; // change in gating variable for one synapse
		for (int t = t_start; t <= step_current; ++t){ // loop through relevant spike history
			t_ring = int(t % history_steps);// index of the history time
			for (unsigned int f = 0; f < spikes_pop[t_ring].size(); ++f){ // loop through every firing neuron at that history time
				i_pre = spikes_pop[t_ring][f];// index of the pre-synaptic firing neuron
				for (unsigned int syn_ind = 0; syn_ind < C[i_pre].size(); ++syn_ind){// loop through all the post-synapses
					j_post = C[i_pre][syn_ind]; // index of the post-synaptic neuron
					// left effective time of transmitter
					left_dt_eff = t + D[i_pre][syn_ind] + steps_trans - step_current; 
					if (left_dt_eff <= steps_trans && left_dt_eff > 0){ // if transmitter still effective
						// restore s-value of interest to the current value at the start of spike
						if (left_dt_eff == steps_trans && s_TALS[i_pre][syn_ind] >= 0){ // at the start of spike and if there exits last spike 
							s_full[i_pre][syn_ind] *= exp_step_table[step_current - s_TALS[i_pre][syn_ind]];
						}
						// update gs_sum (g*s, 0<s<1, g=K>0)
						ds_this_syn = K_trans * (1.0 - s_full[i_pre][syn_ind]); // increase in the form of impulse, (1-s) term for saturation
						gs_sum[j_post] += ds_this_syn * K[i_pre][syn_ind];
						// update s-value of interest
						s_full[i_pre][syn_ind] += ds_this_syn;
						s_full[i_pre][syn_ind] *= exp_step;
					}// if transmitter still effective
					else if (left_dt_eff == 0){ // register s_TALS at the end of spike
						s_TALS[i_pre][syn_ind] = step_current; 
					}
				} // loop through all post-synapses
			} // loop through every firing neuron at that history time
		} // loop through relevant spike history
	} // if pop_ind_pre >=0

	else if (pop_ind_pre == -1){ // if external noisy population
		// Contribution of external spikes, assuming square pulse transmitter release
		// Generate current spikes, note that rate_ext_t is in Hz
		gen.seed(my_seed + step_current);// reseed random engine!!!
		binomial_distribution<int> binml_dist(Num_ext, rate_ext_t[step_current] * (dt / 1000.0));
		auto ext_spikes = bind(binml_dist, gen);
		
		int t_ring = int(step_current % history_steps);// index of the history time
		for (int j = 0; j < N_post; ++j){
			gs_buffer[t_ring][j] = K_trans * K_ext * ext_spikes();
		}
		// Sum over all relevant spike history
		for (int t = 0; t < history_steps; ++t){
			for (int j = 0; j < N_post; ++j){
				gs_sum[j] += gs_buffer[t][j];
			}
		}
	}


	// Calculate chemical currents
	// need V from post population!!
	if (synapses_type == 0){ //AMPA
		for (int j = 0; j < N_post; ++j){
			I[j] = -gs_sum[j] * (V_post->at(j) - V_ex);
		}
	}	
	else if (synapses_type == 1){ //GABA
		for (int j = 0; j < N_post; ++j){
			I[j] = -gs_sum[j] * (V_post->at(j) - V_in);
			// For inhibition, every equation is in the same form as excitation. 
			// Only "V_in" encodes its inhibitory nature.
		}
	}
	else if (synapses_type == 2){ //NMDA
		for (int j = 0; j < N_post; ++j){
			I[j] = -gs_sum[j] * B[(int)round((V_post->at(j) - B_V_min) / B_dV)] * (V_post->at(j) - V_ex);
		}
	}

	// Update gating variable
	for (int j = 0; j < N_post; ++j){ gs_sum[j] *= exp_step; }



}// update





void ChemicalSynapses::set_para(string para_str, char delim){
	if (!para_str.empty()){
		istringstream para(para_str);
		string para_name, para_value_str, line_str; 
		double para_value;
		while (getline(para, line_str)){
			istringstream line_ss(line_str);
			getline(line_ss, para_name, delim); // get parameter name
			getline(line_ss, para_value_str, delim); // get parameter value (assume double)
			stringstream(para_value_str) >> para_value; // from string to numerical value
			if (para_name.find("V_ex") != string::npos){V_ex = para_value;}
			else if (para_name.find("V_in") != string::npos){V_in = para_value;}
			else if (para_name.find("Dt_trans_AMPA") != string::npos){Dt_trans_AMPA = para_value;}
			else if (para_name.find("Dt_trans_GABA") != string::npos){Dt_trans_GABA = para_value;}
			else if (para_name.find("Dt_trans_NMDA") != string::npos){Dt_trans_NMDA = para_value;}
			else if (para_name.find("tau_decay_AMPA") != string::npos){tau_decay_AMPA = para_value;}
			else if (para_name.find("tau_decay_GABA") != string::npos){tau_decay_GABA = para_value;}
			else if (para_name.find("tau_decay_NMDA") != string::npos){tau_decay_NMDA = para_value;}
			else {cout << "Unrecognized parameter: " << para_name << endl;}
		}
	}
	// re-initialise it!
	init();
}


string ChemicalSynapses::dump_para(char delim){
	stringstream dump;


	dump << "pop_ind_pre" << delim << pop_ind_pre << delim << endl;
	dump << "pop_ind_post" << delim << pop_ind_post << delim << endl;
	dump << "synapses_type" << delim << synapses_type << delim << endl;

	dump << "V_ex" << delim << V_ex << delim << endl;
	dump << "V_in" << delim << V_in << delim << endl;

	dump << "seed" << delim << my_seed << delim << endl;
	
	if (synapses_type == 0){
		dump << "Dt_trans_AMPA" << delim << Dt_trans_AMPA << delim << endl;
		dump << "tau_decay_AMPA" << delim << tau_decay_AMPA << delim << endl;
	}
	else if (synapses_type == 1){
		dump << "Dt_trans_GABA" << delim << Dt_trans_GABA << delim << endl;
		dump << "tau_decay_GABA" << delim << tau_decay_GABA << delim << endl;
	}
	else if (synapses_type == 2){
		dump << "Dt_trans_NMDA" << delim << Dt_trans_NMDA << delim << endl;
		dump << "tau_decay_NMDA" << delim << tau_decay_NMDA << delim << endl;
	}

	return dump.str();
}

void ChemicalSynapses::output_results(ofstream& output_file, char delim, char indicator){
	// SYND001 # synapse parameters
	// count number of variables
	stringstream dump_count;
	string para_str = dump_para(delim);
	dump_count << para_str;
	string str_temp;
	int var_number = 0;
	while(getline(dump_count,str_temp)){++var_number;} // count number of variables
	output_file << indicator << " SYND001" << endl;
	output_file << var_number << delim << endl;
	output_file << para_str;
}



void ChemicalSynapses::recv_pop_data(vector<Neurons> &NeuronPopArray, int step_current){
	// get current spikes from pre-pop
	if (pop_ind_pre >= 0){
		int t_ring_current = int(step_current % history_steps);
		spikes_pop[t_ring_current] = NeuronPopArray[pop_ind_pre].spikes_current;
	}
	// get current V from post-pop
	V_post = &(NeuronPopArray[pop_ind_post].V); // This is problematic!!!
	
}


void ChemicalSynapses::send_pop_data(vector<Neurons> &NeuronPopArray){
	
	// send currents to post-pop
	//AMPA
	if (synapses_type == 0){
		for (int j = 0; j < N_post; ++j){
			NeuronPopArray[pop_ind_post].I_AMPA[j] += I[j];
		}
	}
	//GABA
	else if (synapses_type == 1){
		for (int j = 0; j < N_post; ++j){
			NeuronPopArray[pop_ind_post].I_GABA[j] += I[j];
		}
	}
	//NMDA
	else if (synapses_type == 2){
		for (int j = 0; j < N_post; ++j){
			NeuronPopArray[pop_ind_post].I_NMDA[j] += I[j];
		}
	}
}
