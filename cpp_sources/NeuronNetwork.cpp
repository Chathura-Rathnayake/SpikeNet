#include "NeuronNetwork.h"
#include <iostream>
//#include <random>
#include <vector>
#include <iterator>     // std::back_inserter
#include <algorithm>    // std::for_each, copy
#include <numeric>      // std::accumulate
#include <string.h>     // for memcpy
#include <ctime>

using namespace std;

NeuronNetwork::NeuronNetwork(vector<int> N_array_input, double dt_input, int step_tot_input){

	N_array = N_array_input;
	dt = dt_input;
	step_tot = step_tot_input;	Num_pop = N_array.size();

	runaway_killed = false;
	step_killed = -1;
};


void NeuronNetwork::update(int step_current){

	if (runaway_killed == false){ // if not runaway_killed
		/*------------------------------------------------------------------------------------------------------*/
	
		// Update neuron states
		// Pre-coupling update
	
		for (int pop_ind = 0; pop_ind < Num_pop; ++pop_ind){
			// Update spikes and nonref
			NeuronPopArray[pop_ind].update_spikes(step_current); // this must always be the first operation!!!
			// Update action potential for electrical coupling
			// ElectricalSynapsesArray[i_pre][i_pre].update_action_potential(NeuronPopArray[i_pre], step_current);

			// check runaway activity
			runaway_killed |= NeuronPopArray[pop_ind].runaway_killed;
			if (runaway_killed == true){
				step_killed = step_current;
			}
		}


	
		/*------------------------------------------------------------------------------------------------------*/
		// Chemical Coupling
		for (unsigned int syn_ind = 0; syn_ind < ChemicalSynapsesArray.size(); ++syn_ind){
				ChemicalSynapsesArray[syn_ind].recv_pop_data(NeuronPopArray, step_current);
				// recv_data should be more optimized if using MPI!
				ChemicalSynapsesArray[syn_ind].update(step_current);
				ChemicalSynapsesArray[syn_ind].send_pop_data(NeuronPopArray);
		}
		
		// Electrical coupling
		

		/*------------------------------------------------------------------------------------------------------*/
		// Update membrane potential
		// Post-coupling update
		for (int pop_ind = 0; pop_ind < Num_pop; ++pop_ind){
			// Update membrane potential
			NeuronPopArray[pop_ind].update_V(step_current); 
			// Data sampling
			NeuronPopArray[pop_ind].sample_data(step_current); // this must always be the last operation
		}
	
	} // if not runaway_killed


	// Countdown
	if (step_current == 0){
		cout << "Commencing countdown, engines on..." << flush;	
		// if not "flush", output will be delayed in buffer
	}
	int steps_left = step_tot-step_current-1;
	if ((steps_left % (step_tot/10)) == 0){
		cout << steps_left/(step_tot/10) << "..." << flush;
	}
	if (steps_left == 0){cout << endl;}
}




