// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
namespace Microsoft.Quantum.Samples.DatabaseSearch {
    
    open Microsoft.Quantum.Primitive;
    open Microsoft.Quantum.Extensions.Convert;
    open Microsoft.Quantum.Extensions.Math;
    open Microsoft.Quantum.Canon;
    
    
    //////////////////////////////////////////////////////////////////////////
    // Introduction //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////
    
    // This sample will walk through several examples of searching a database
    // of N elements for a particular marked item using just O(1/√N) queries
    // to the database. In particular, we will follow Grover's algorithm, as
    // described in the standard library guide.
    
    // We will model the database by an oracle D that acts to map indices
    // to a flag indicating whether a given index is marked. In particular,
    // let |z〉 be a single-qubit computational basis state (that is, either
    // |0〉 or |1〉, and let |k〉 be a state representing an index k ∈ {0, 1,
    // …, N }. Then
    
    //     D |z〉 |k〉 = |z ⊕ xₖ〉 |k〉,
    
    // where x = x₀ x₁ … x_{N - 1} is a binary string such that xₖ is 1
    // if and only if the kth item is marked, and where ⊕ is the classical
    // exclusive OR gate. Note that given this definition, we know how D
    // transforms arbitrary states by linearity -- given an input state
    // that is a linear combination of orthogonal states |z〉|k〉 summed over the
    // z and k indices, D acts on each state independently.
    
    // First, we work out an example of how to construct and apply D without
    // using the canon. We then implement all the steps of Grover search
    // manually using this database oracle. Second, we show the amplitude
    // amplification libraries provided with the canon can make this task
    // significantly easier.
    
    //////////////////////////////////////////////////////////////////////////
    // Database Search with Manual Oracle Definitions ////////////////////////
    //////////////////////////////////////////////////////////////////////////
    
    // For the first example, we start by hard coding an oracle D
    // that always marks only the item k = N - 1 for N = 2^n and for
    // n a positive integer. Note that n is the number of qubits needed to
    // encode the database element index k.
    
    /// # Summary
    /// Given a qubit to use to store a mark bit and a register corresponding
    /// to a database, marks the first qubit conditioned on the register
    /// state being the all-ones state |11…1〉.
    ///
    /// # Input
    /// ## markedQubit
    /// A qubit to be targeted by an `X` operation controlled on whether
    /// the state of `databaseRegister` corresponds to a market item.
    /// ## databaseRegister
    /// A register representing the target of a query to the database.
    ///
    /// # Remarks
    /// Implements the operation
    ///
    ///     |z〉 |k〉 ↦ |z ⊕ f(k)〉 |k〉,
    ///
    /// where f(k) = 1 if and only if k = 2^(Length(databaseRegister)) - 1 and
    /// 0 otherwise.
    operation DatabaseOracle (markedQubit : Qubit, valueRegister : Qubit[], searchValue: Int) : Unit {
        
        body (...) {		    
			// Note: As X accepts a Qubit, and ControlledOnInt only
            // accepts Qubit[], we use ApplyToEachCA(X, _) which accepts
            // Qubit[] even though the target is only 1 Qubit.
            (ControlledOnInt(searchValue, ApplyToEachCA(X, _)))(valueRegister, [markedQubit]);
        }
        
        adjoint invert;
    }
    
    
    // Grover's algorithm for quantum database searching requires that we
    // prepare the state given by the uniform superposition over all
    // computational basis states,
    
    //     |u〉 = Σₖ |k〉 = H^{⊗ n} |00…0〉,
    
    // where we have labeled n-qubit states by the integers formed by
    // interpreting their computational basis labels as big-endian
    // representations. For example, |2〉 in this notation is |10〉 in the
    // computational basis of two qubits.
    
    // Resolving this convention, then,
    
    //     |u〉 = |++…+〉.
    
    // This state is easy to implement given the input state |00…0〉, and we
    // call the oracle that does so U.
    
    /// # Summary
    /// Given a register of qubits initially in the state |00…0〉, prepares
    /// a uniform superposition over all computational basis states.
    ///
    /// # Input
    /// ## databaseRegister
    /// A register of n qubits initially in the |00…0〉 state.
    operation UniformSuperpositionOracle (keyRegister : Qubit[]) : Unit {
        
        body (...) {
            let nQubits = Length(keyRegister);
            
            for (idxQubit in 0 .. nQubits - 1) {
                H(keyRegister[idxQubit]);
            }
        }
        
        adjoint invert;
    }
    
	// Encode database as entanglement between key/value registers
	operation EncodeDatabase(keyRegister: Qubit[], valueRegister: Qubit[]) : Unit
	{	
		body (...) {
			(ControlledOnInt(0, SetRegisterToInt(3, _)))(keyRegister, valueRegister);
			(ControlledOnInt(1, SetRegisterToInt(2, _)))(keyRegister, valueRegister);
			(ControlledOnInt(2, SetRegisterToInt(0, _)))(keyRegister, valueRegister);
			(ControlledOnInt(3, SetRegisterToInt(1, _)))(keyRegister, valueRegister);
		}
		adjoint auto;
		controlled auto;
		controlled adjoint auto;
	}

	// Set target register to integer value
	operation SetRegisterToInt(value: Int, register : Qubit[]) : Unit {
		body (...) {
			let nQubits = Length(register);
			let bitstring = BoolArrFromPositiveInt(value, nQubits);
			for (idxQubit in 0..nQubits - 1) {
				if (bitstring[idxQubit]) {
					X(register[idxQubit]);
				}
			}
		}
		adjoint auto;
		controlled auto;
		controlled adjoint auto;
	}
    
    // We will define the state preparation oracle as a black-box unitary that
    // creates a uniform superposition of states using
    // `UniformSuperpositionOracle` U, then marks the target state using the
    // `DatabaseOracle` D. When acting on the input state |00…0〉, this prepares
    // the start state
    
    // |s〉 = D|0〉|u〉 = DU|0〉|0〉 = |1〉|N-1〉/√N + |0〉(|0〉+|1〉+...+|N-2〉)/√N.
    
    // Let us call DU the state preparation oracle. Note that if we were to
    // measure the marked qubit, we would obtain |1〉 and hence the index |N-1〉
    // with probability 1/N, which coincides with the classical random search
    // algorithm.
    
    // It is helpful to think of 1/√N = sin(θ) as the sine of an angle θ. Thus
    // the start state |s〉 = sin(θ) |1〉|N-1〉 + cos(θ) |0〉(|0〉+|1〉+...+|N-2〉)
    // is a unit vector in a two-dimensional subspace spanned by the
    // orthogonal states |1〉|N-1〉, and |0〉(|0〉+|1〉+...+|N-2〉).
    
    /// # Summary
    /// Given a register of qubits initially in the state |00…0〉, prepares
    /// the start state |1〉|N-1〉/√N + |0〉(|0〉+|1〉+...+|N-2〉)/√N.
    ///
    /// # Input
    /// ## markedQubit
    /// Qubit that indicates whether database element is marked.
    /// ## databaseRegister
    /// A register of n qubits initially in the |00…0〉 state.
    operation StatePreparationOracle (markedQubit : Qubit, keyRegister : Qubit[], valueRegister : Qubit[], searchValue: Int) : Unit {
        
        body (...) {
            UniformSuperpositionOracle(keyRegister);
			EncodeDatabase(keyRegister, valueRegister);
            DatabaseOracle(markedQubit, valueRegister, searchValue);
        }
        
        adjoint invert;
    }
    
    
    // Grover's algorithm requires reflections about the marked state and the
    // start state. A reflection R is a unitary operator with eigenvalues ± 1,
    // and reflection about an arbitrary state |ψ〉 may be defined as
    
    // R = 1 - 2 |ψ〉〈ψ|.
    
    // Thus R|ψ〉 = -|ψ〉 applies a -1 phase, and R(|ψ〉) on any other state applies a
    // +1 phase. We now implement these reflections.
    
    /// # Summary
    /// Reflection `RM` about the marked state.
    ///
    /// # Input
    /// ## markedQubit
    /// Qubit that indicated whether database element is marked.
    operation ReflectMarked (markedQubit : Qubit) : Unit {
        
        // Marked elements always have the marked qubit in the state |1〉.
        R1(PI(), markedQubit);
    }
    
    
    /// # Summary
    /// Reflection about the |00…0〉 state.
    ///
    /// # Input
    /// ## databaseRegister
    /// A register of n qubits initially in the |00…0〉 state.
    operation ReflectZero (databaseRegister : Qubit[]) : Unit {
        
        let nQubits = Length(databaseRegister);
        
        for (idxQubit in 0 .. nQubits - 1) {
            X(databaseRegister[idxQubit]);
        }
        
        Controlled Z(databaseRegister[1 .. nQubits - 1], databaseRegister[0]);
        
        for (idxQubit in 0 .. nQubits - 1) {
            X(databaseRegister[idxQubit]);
        }
    }
    
    
    /// # Summary
    /// Reflection `RS` about the start state DU|0〉|0〉.
    ///
    /// # Input
    /// ## markedQubit
    /// Qubit that indicated whether database element is marked.
    /// ## databaseRegister
    /// A register of n qubits initially in the |00…0〉 state.
    operation ReflectStart (markedQubit : Qubit, keyRegister : Qubit[], valueRegister : Qubit[], searchValue: Int) : Unit {
        
        Adjoint StatePreparationOracle(markedQubit, keyRegister, valueRegister, searchValue);
        ReflectZero([markedQubit] + keyRegister);
        StatePreparationOracle(markedQubit, keyRegister, valueRegister, searchValue);
    }
    
    
    // We may then search our database for the marked elements by performing
    // on the start state a sequence of alternating reflections about the
    // marked state and the start state. The product RS · RM is known as the
    // Grover iterator, and each application of it rotates |s〉 in the two-
    // dimensional subspace by angle 2θ. Thus M application of it creates the
    // state
    
    // (RS · RM)^M |s〉 = sin((2M+1)θ) |1〉|N-1〉
    //                  + cos((2M+1)θ) |0〉(|0〉+|1〉+...+|N-2〉)
    
    // Observe that if we choose M = O(1/√N), we can obtain an O(1)
    // probability of obtaining the marked state |1〉. This is the Quantum
    // speedup!
    
    /// # Summary
    /// Prepares the start state and boosts the amplitude of the marked
    /// subspace by a sequence of reflections about the marked state and the
    /// start state.
    ///
    /// # Input
    /// ## nIterations
    /// Number of applications of the Grover iterate (RS · RM).
    /// ## markedQubit
    /// Qubit that indicated whether database element is marked.
    /// ## databaseRegister
    /// A register of n qubits initially in the |00…0〉 state.
    operation QuantumSearch (nIterations : Int, markedQubit : Qubit, keyRegister : Qubit[], valueRegister : Qubit[], searchValue: Int) : Unit {
        
		StatePreparationOracle(markedQubit, keyRegister, valueRegister, searchValue);
        
        // Loop over Grover iterates.
        for (idx in 0 .. nIterations - 1) {
            ReflectMarked(markedQubit);
            ReflectStart(markedQubit, keyRegister, valueRegister, searchValue);
        }
    }
    
    
    // Let us now create an operation that allocates qubits for Grover's
    // algorithm, implements the `QuantumSearch`, measures the marked qubit
    // the database register, and returns the measurement results.
    
    /// # Summary
    /// Performs quantum search for the marked element and returns an index
    /// to the found element in binary format. Finds the marked element with
    /// probability sin²((2*nIterations+1) sin⁻¹(1/√N)).
    ///
    /// # Input
    /// ## nIterations
    /// Number of applications of the Grover iterate (RS · RM).
    /// ## nDatabaseQubits
    /// Number of qubits in the database register.
    ///
    /// # Output
    /// Measurement outcome of marked Qubit and measurement outcomes of
    /// the database register.
    operation ApplyQuantumSearch (nIterations : Int, nKeyQubits : Int, nValueQubits : Int, searchValue: Int) : (Result, Result[]) {
        
        // Allocate variables to store measurement results.
        mutable resultSuccess = Zero;
        mutable resultElement = new Result[nKeyQubits];
        
		let nDatabaseQubits = nKeyQubits + nValueQubits;

        // Allocate nDatabaseQubits + 1 qubits. These are all in the |0〉
        // state.
        using (qubits = Qubit[nDatabaseQubits + 1]) {
            
            // Define marked qubit to be indexed by 0.
            let markedQubit = qubits[0];
            
            // Let all other qubits be the database register.
            let keyRegister = qubits[1 .. nKeyQubits];
            let valueRegister = qubits[nKeyQubits + 1 .. nKeyQubits + nValueQubits];
            
            // Implement the quantum search algorithm.
            QuantumSearch(nIterations, markedQubit, keyRegister, valueRegister, searchValue);
            
            // Measure the marked qubit. On success, this should be One.
            set resultSuccess = M(markedQubit);
            
            // Measure the state of the database register post-selected on
            // the state of the marked qubit.
            set resultElement = MultiM(keyRegister);
            let resultInt = PositiveIntFromResultArr(resultElement);
			let valueElement = MultiM(valueRegister);
			let valueInt = PositiveIntFromResultArr(valueElement);			
			Message($"key: {resultElement} keyInt: {resultInt} value: {valueElement} valueInt: {valueInt}");
            
            // These reset all qubits to the |0〉 state, which is required
            // before deallocation.
            if (resultSuccess == One) {
                X(markedQubit);
            }
            
            for (idxResult in 0 .. nKeyQubits - 1) {
                
                if (resultElement[idxResult] == One) {
                    X(keyRegister[idxResult]);
                }
            }

			for (idxResult in 0 .. nValueQubits - 1) {
                
                if (valueElement[idxResult] == One) {
                    X(valueRegister[idxResult]);
                }
            }
        }
        
        // Returns the measurement results of the algorithm.
        return (resultSuccess, resultElement);
    }   

}


