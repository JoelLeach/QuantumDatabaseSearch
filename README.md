# Quantum Database Key/Value Search Sample #

[Microsoft's Q# Database Search Sample](https://github.com/Microsoft/Quantum/tree/master/Samples/src/DatabaseSearch) walks through Grover's search algorithm. Oracles implementing the database are explicitly constructed together with all steps of the algorithm. This is a modified version of the first example (of two) in the sample.

The Microsoft sample searches for a specific index/key in the database, which is not very useful. This code expands upon that sample to search a list of values in a database and return the corresponding key.

## Details ##
As a beginner in the world of Quantum Computing and a classical programmer (i.e., I don't speak Quantum Mechanics), Grover's search algorithm looks attractive. It promises to search unsorted databases on a quantum computer in fewer steps than a classical computer.  The algorithm relies on an "black box oracle" to determine which value(s) in the database meet the search criteria.  It sounds easy enough, but the examples I found were focused on demonstrating Grover's algorithm, not on how to construct a useful oracle.

The Microsoft example searches a three-qubit register for the value 111 (7).  This register represents an index (think row number or primary key in classical database terms).  When the index is found, a fourth qubit (markedQubit) is set to 1 (true).  The example does demonstrate that the index can be found in fewer steps than a random classical search.  However, you might be wondering... if I already know the index (7), why would I need to search for it?  Exactly.

Let's expand upon the example by associating values with each index. Imagine we have a database table with two columns name "key" and "value".  The key is a pointer to a specific row in the table, but otherwise does not contain any useful information.  The value contains information that is useful, and it is also the column that we want to query.  Our table has four rows:

- Key = 0, Value = 3
- Key = 1, Value = 2
- Key = 2, Value = 0
- Key = 3, Value = 1

We'll have one two-qubit register that contains the keys, and a separate two-qubit register that contains the values.  How do we associate the key register with specific values in the value register?  The approach taken here is one of entanglement.  That is best demonstrated with a circuit. [Click here to see the actual Quirk circuit](https://algassert.com/quirk#circuit={%22cols%22:[[%22H%22,%22H%22],[%22%E2%80%A6%22,%22%E2%80%A6%22],[%22%E2%97%A6%22,%22%E2%97%A6%22,%22X%22,%22X%22],[%22%E2%80%A2%22,%22%E2%97%A6%22,1,%22X%22],[%22%E2%97%A6%22,%22%E2%80%A2%22],[%22%E2%80%A2%22,%22%E2%80%A2%22,%22X%22],[1,1,%22Chance2%22],[1,1,%22%E2%80%A6%22,%22%E2%80%A6%22],[1,1,%22%E2%97%A6%22,%22%E2%80%A2%22,%22X%22]]}).

![Key/Value Oracle circuit](https://raw.githubusercontent.com/JoelLeach/QuantumDatabaseSearch/master/QuirkCircuit.PNG "Key/Value Oracle Circuit")

Note that this circuit contains only the oracle.  It does not implement all of Grover's algorithm. 

- The top two qubits are the key register, the next two are the value register, and the bottom qubit is the marked qubit.  
- The first section puts the key register in a uniform superposition using Haramard gates, as required by Grover's algorithm.
- The second section is where the keys are associated with the values via entanglement. The Anti-Control (empty dot) represents 0 and the Control (filled dot) represents 1. You can see we have all four values represented in the key register.
- Each key is then entangled with a corresponding value in the value register by applying X (NOT) gates.  So, when the key register is 0, then the value register will be set to 3.  When the key is 1, the value is set to 2, and so on on.  
- A probability display is included in the circuit, which shows a 25% chance for each of the four values while the key register is in a superposition (as expected).  For testing purposes, you could remove the H gates and replace them with X gates to enter a specific input into the circuit and see how it flows.  For example, put an X gate on the first qubit to change the key to 1 (01), then you'll see the probability display change to 100% for value 2 (10).
- The third section of the circuit is the search oracle.  The value register is entangled with the marked qubit.  In this example, the desired value is 2.  When the value register contains 2, the marked qubit will be set to 1.
- Grover's algorithm looks at the key register and marked qubit.  The search oracle looks at the value register and sets the marked qubit.  This will cause key 1 to be amplified when the value is 2.

It's interesting to note that the keys and values are not stored in the qubits, but rather in the circuit/program.  You could say it's not really a database per se.  It's more like a switch/case statement, but one that can run on a superposition of values.

Here is the Q# code that encodes the database as entanglement between the two registers:

```csharp
(ControlledOnInt(0, SetRegisterToInt(3, _)))(keyRegister, valueRegister);
(ControlledOnInt(1, SetRegisterToInt(2, _)))(keyRegister, valueRegister);
(ControlledOnInt(2, SetRegisterToInt(0, _)))(keyRegister, valueRegister);
(ControlledOnInt(3, SetRegisterToInt(1, _)))(keyRegister, valueRegister);
```

The syntax is a little odd, but the logic is the same as the Quirk circuit. When the key register contains 0, set the value register to 3, and so on...  The search oracle is coded in a similar fashion.

```csharp
(ControlledOnInt(searchValue, ApplyToEachCA(X, _)))(valueRegister, [markedQubit]);
```

This seems to work, but not without caveats.  A major problem is that the database has to be encoded (i.e. the entanglement between the key and value registers has to be setup) every time the oracle is queried.  The uniform superposition (Hadamard gates) is applied to the key register on each iteration, and that appears to remove any entanglement that was previously set.  I'm not sure that is a technically accurate statement, but it only works if you setup the entanglement after the superposition is applied.

If you'd like to learn more, here are some references you may find helpful:

- [Quantum Circuit Design and Analysis for Database Search Applications](https://ieeexplore.ieee.org/document/4383247)
- [The Building and Optimization of Quantum Database](https://www.sciencedirect.com/science/article/pii/S1875389212006980)
- [Quantum Pattern Matching](https://arxiv.org/abs/quant-ph/0508237)
- [Microsoft Quantum Development Kit Docs](https://docs.microsoft.com/en-us/quantum/?view=qsharp-preview)
- [Microsoft Quantum Development Kit Samples](https://github.com/Microsoft/Quantum)
- [Q# libraries for the Quantum Development Kit](https://github.com/Microsoft/QuantumLibraries)

## Running the Sample ##

- Install the [Microsoft Quantum Development Kit](https://www.microsoft.com/en-us/quantum/development-kit).
- Open the `DatabaseSearchKeyValue.sln` solution in Visual Studio.
- Press Start in Visual Studio to run the sample.

## Manifest ##

- [DatabaseSearch.qs](./DatabaseSearch.qs): Q# code implementing quantum operations for this sample.
- [Program.cs](./Program.cs): C# code to interact with and print out results of the Q# operations for this sample.
- [DatabaseSearchKeyValue.csproj](./DatabaseSearchKeyValue.csproj): Main C# project for the sample.
