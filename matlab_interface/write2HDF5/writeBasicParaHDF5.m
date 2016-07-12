function writeBasicParaHDF5(FID, dt, step_tot, N)
% write basic parameters
%      FID: file id for writing data
%       dt: time step size in ms
% step_tot: total number of simulation steps
%        N: vector for number of neurons in each population


hdf5write(FID,'/config/Net/INIT001/N',N,'WriteMode','append');
hdf5write(FID,'/config/pops/n_pops',int32(length(N)),'WriteMode','append');


hdf5write(FID,'/config/Net/INIT002/dt',dt,'WriteMode','append');
hdf5write(FID,'/config/Net/INIT002/step_tot',step_tot,'WriteMode','append');

end
