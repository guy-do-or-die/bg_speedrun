use std::hash::poseidon::bn254::hash_1;
use std::hash::poseidon::bn254::hash_2;
////// Checkpoint 4 //////
// use binary_merkle_root::binary_merkle_root;

fn main(
    // public inputs
    root: pub Field,
    nullifier_hash: pub Field,
    vote: pub Field, // 0 or 1
    // private inputs
    nullifier: Field,
    secret: Field,
    path_indices: Field, // index
    siblings: [Field; 16],
) {
    // 1. Calculate commitment
    // commitment = hash(secret, nullifier)
    let commitment = hash_2([secret, nullifier]);

    // 2. Calculate nullifier hash
    // nullifier_hash = hash(nullifier, secret)
    // Using swapped order to distinguish from commitment. 
    // Ideally we'd use a different hash or domain separator, but this works for simple unique constraints.
    let calculated_nullifier_hash = hash_2([nullifier, secret]);
    assert(calculated_nullifier_hash == nullifier_hash);

    // 3. Verify Merkle Proof
    // Use std::merkle::compute_merkle_root
    let calculated_root = std::merkle::compute_merkle_root(commitment, path_indices, siblings);
    assert(calculated_root == root);

    // 4. Constrain vote to be 0 or 1
    assert(vote * (vote - 1) == 0);
}
