#!/bin/env python

import functools
import subprocess
import sys

def with_file(filename, mode='r'):
    """
    Decorator generating function for wrapping a function
    invocation around a given file and mode
    """
    if len(sys.argv) >= 2:
        postfix = '.%d' % (int(sys.argv[1]))
    else:
        postfix = ''
    def decorator(func):
        def wrapper(*args, **kwargs):
            with open(filename + postfix, mode) as f:
                function = functools.partial(func, f)
                return function(*args, **kwargs)
        return wrapper
    return decorator

def process_line(line):
	values = line.strip().split()
	suite = values[0]
	bmark = values[1]
	rep = int(values[2])
	cores = int(values[3])
	return [suite, bmark, rep, cores]

@with_file('completed_experiments', 'a+')
def read_completed_experiments(file):
	experiments = []
	for line in file:
		experiments.append(process_line(line))	
	return experiments
		
@with_file('experiment_list')
def read_experiment_list(file):
	"""
	Experiment format is 'suite bmark rep cores'
	"""
	experiments = []
	for line in file:
		experiments.append(process_line(line))
	return experiments
		
@with_file('completed_experiments', 'a+')
def write_complete_experiment(file, experiment):
    """
    Format is 'suite bmark rep cores time avg_ipc estimated_bubble'
    """
    suite = experiment[0]
    bmark = experiment[1]
    rep =  int(experiment[2])
    cores = int(experiment[3])
    time = float(experiment[4])
    mean_ipc = float(experiment[5])
    mean_bubble = float(experiment[6])
    median_ipc = float(experiment[7])
    median_bubble = float(experiment[8])
    p95_ipc = float(experiment[9])
    p95_bubble = float(experiment[10])
    p99_ipc = float(experiment[11])
    p99_bubble = float(experiment[12])
    entry = "%(suite)s %(bmark)s %(rep)d %(cores)d %(time)f %(mean_ipc)f %(mean_bubble)f %(median_ipc)f %(median_bubble)f %(p95_ipc)f %(p95_bubble)f %(p99_ipc)f %(p99_bubble)f\n" % locals()
    file.write(entry)
    file.flush()

def run_experiment(experiment):
    cmd = ['bash', './run_experiment.sh'] + experiment
    cmd = [str(e) for e in cmd]
    print("Running command: " + str(cmd))
    output = subprocess.check_output(cmd)
    values = output.split()
    experiment += values    
    return experiment

def main():
    print("Reading experiments")
    experiments = read_experiment_list()
    print("Reading compete experiements")
    complete_experiments = read_completed_experiments()

    print("There are %d experiements and %d complete experiements" % (len(experiments), len(complete_experiments)))

    new_experiments = []	
    for experiment in experiments:
        if experiment not in complete_experiments:
            new_experiments.append(experiment)
	
    print("There are %d experiments to run" % (len(new_experiments)))
    print("New experiments: " + str(new_experiments))

    for experiment in new_experiments:
        try:
            print("Running experiement: " + str(experiment))
            results = run_experiment(experiment)
            print("Experiement complete, writing results...")
            write_complete_experiment(results)
            print("Finished writing results")
        except Exception as e:
            print("Error: Failed to run experiement (" + str(experiment) + ")")
            print("Exception was: " + str(e))

if __name__ == '__main__':
	main()
