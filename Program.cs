// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.


using Microsoft.Quantum.Simulation.Core;
using Microsoft.Quantum.Simulation.Simulators;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Microsoft.Quantum.Samples.DatabaseSearch
{
    class Program
    {
        public static void Pause()
        {
            System.Console.WriteLine("\n\nPress any key to continue...\n\n");
            System.Console.ReadKey();
        }

        static void Main(string[] args)
        {

            #region Setup

            // We begin by defining a quantum simulator to be our target
            // machine.
            var sim = new QuantumSimulator(throwOnReleasingQubitsNotInZeroState: true);

            #endregion

            // We now define the size `N` = 2^n of the database to searched in terms of 
            // number of qubits `n`. 
            var nKeyQubits = 2;
            var nValueQubits = 2;
            var databaseSize = Math.Pow(2.0, nKeyQubits);

            // Set the value to search for
            var searchValue = 0;

            // We now execute the classical random search and verify that the success 
            // probability matches the classical result of 1/N. Let us repeat 100
            // times to collect enough statistics.
            var classicalSuccessProbability = 1.0 / databaseSize;
            var repeats = 10;
            var successCount = 0;

            #region Random Database Search with Manual Oracle Definitions

            // Let us investigate the success probability of classical random search.
            // This corresponds to the case where we only prepare the start state, and
            // do not perform any Grover iterates to amplify the marked subspace.
            var nIterations = 0;

            Console.Write(
                $"Classical random search for marked element in database.\n" +
                $"  Database size: {databaseSize}.\n" +
                $"  Success probability:  {classicalSuccessProbability}\n\n");



            foreach (var idxAttempt in Enumerable.Range(0, repeats))
            {
                // Each operation has a static method called Run which takes a simulator as
                // an argument, along with all the arguments defined by the operation itself.  
                var task = ApplyQuantumSearch.Run(sim, nIterations, nKeyQubits, nValueQubits, searchValue);
                
                // We extract the return value of the operation by getting the Results property.
                var data = task.Result;

                // Extract the marked qubit state
                var markedQubit = data.Item1;
                var databaseRegister = data.Item2.ToArray();

                successCount += markedQubit == Result.One ? 1 : 0;

                // Print the results of the search every 100 attempts
                if ((idxAttempt + 1) % 1 == 0)
                {

                    Console.Write(
                        $"Attempt {idxAttempt}. " +
                        $"Success: {markedQubit},  " +
                        $"Probability: {Math.Round((double)successCount / ((double)idxAttempt + 1),3)} " +
                        $"Found database index {string.Join(", ", databaseRegister.Select(x => x.ToString()).ToArray())} \n");
                }
            }

            Pause();

            #endregion


            #region Quantum Database Search with Manual Oracle Definitions

            // Let us investigate the success probability of the quantum search.
            
            // We now perform Grover iterates to amplify the marked subspace.
            nIterations = 1;

            // Number of queries to database oracle.
            var queries = nIterations * 2 + 1;

            // We now execute the quantum search and verify that the success 
            // probability matches the theoretical prediction. 
            classicalSuccessProbability = 1.0 / databaseSize;
            var quantumSuccessProbability = Math.Pow(Math.Sin((2.0 * (double)nIterations + 1.0) * Math.Asin(1.0 / Math.Sqrt(databaseSize))),2.0);
            //repeats = 100;
            successCount = 0;

            Console.Write(
                $"\n\nQuantum search for marked element in database.\n" +
                $"  Database size: {databaseSize}.\n" +
                $"  Classical success probability: {classicalSuccessProbability}\n" +
                $"  Queries per search: {queries} \n" +
                $"  Quantum success probability: {quantumSuccessProbability}\n\n");



            foreach (var idxAttempt in Enumerable.Range(0, repeats))
            {
                // Each operation has a static method called Run which takes a simulator as
                // an argument, along with all the arguments defined by the operation itself.  
                var task = ApplyQuantumSearch.Run(sim, nIterations, nKeyQubits, nValueQubits, searchValue);

                // We extract the return value of the operation by getting the Results property.
                var data = task.Result;

                // Extract the marked qubit state
                var markedQubit = data.Item1;
                var databaseRegister = data.Item2.ToArray();

                successCount += markedQubit == Result.One ? 1 : 0;

                // Print the results of the search every 10 attempts
                if ((idxAttempt + 1) % 1 == 0)
                {
                    var empiricalSuccessProbability = Math.Round((double)successCount / ((double)idxAttempt + 1), 3);

                    // This is how much faster the quantum algorithm performs on average
                    // over the classical search.
                    var speedupFactor = Math.Round(empiricalSuccessProbability / classicalSuccessProbability / (double)queries, 3);

                    Console.Write(
                        $"Attempt {idxAttempt}. " +
                        $"Success: {markedQubit},  " +
                        $"Probability: {empiricalSuccessProbability} " +
                        $"Speedup: {speedupFactor} " +
                        $"Found database index {string.Join(", ", databaseRegister.Select(x => x.ToString()).ToArray())} \n");
                }
            }

            Pause();

            #endregion
        }
    }
}
