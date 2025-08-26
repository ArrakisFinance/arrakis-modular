# Echidna Fuzzing Setup for PancakeSwapV3StandardModulePrivate

This document explains how to use the Echidna fuzzing setup for testing the PancakeSwapV3StandardModulePrivate contract.

## Prerequisites

1. **Install Echidna**:
   ```bash
   curl -L https://github.com/crytic/echidna/releases/latest/download/echidna-2.2.1-Linux.tar.gz | tar -xz
   sudo mv echidna /usr/local/bin/
   ```

2. **Set up environment variables**:
   ```bash
   export ALCHEMY_API_KEY="your_alchemy_api_key_here"
   ```

3. **Install Foundry dependencies**:
   ```bash
   forge install
   ```

## Configuration

The Echidna configuration is defined in `echidna.yaml`:

- **Fork**: Ethereum mainnet at block 23225174
- **Test Mode**: assertions
- **Test Limit**: 50,000 function calls
- **Sequence Length**: 30 calls per sequence
- **Contract Address**: Arrakis factory on mainnet (`0x820FB8127a689327C863de8433278d6181123982`)
- **Coverage**: Enabled with HTML and text output

## Test Contract Structure

The `PancakeSwapV3InvariantFuzzing` contract includes:

### Setup Functions
- `_setupModule()`: Creates PancakeSwapV3StandardModulePrivate implementation
- `_whitelistBeacon()`: Whitelists the module beacon in the public registry

### Fuzz Test Functions
1. **`fuzz_create_vault()`**: Tests vault creation with random parameters
   - Assertions: Valid vault address, correct owner, proper token setup
   
2. **`fuzz_deposit()`**: Tests deposits with random amounts
   - Requirements: Vault exists, amounts > 0
   - Assertions: Balances increase, total supply increases, solvency maintained
   
3. **`fuzz_withdraw()`**: Tests withdrawals with random proportions
   - Requirements: Vault exists, user has shares
   - Assertions: Balances decrease properly, solvency maintained, no over-withdrawal
   
4. **`fuzz_rebalance()`**: Tests rebalancing operations
   - Requirements: Vault exists, caller is executor
   - Assertions: Vault remains solvent, value preservation within tolerance

### Invariant Checks
- **`echidna_withdrawals_not_exceed_deposits()`**: Ensures total withdrawals ≤ total deposits
- **`echidna_vault_count_reasonable()`**: Ensures vault count stays within bounds
- **`echidna_vault_solvency()`**: Ensures vault remains solvent if it exists

## Running Echidna

### Method 1: Using the Script
```bash
./run_echidna.sh
```

### Method 2: Direct Command
```bash
echidna . --contract PancakeSwapV3InvariantFuzzing --config echidna.yaml
```

### Method 3: With Custom Parameters
```bash
echidna . --contract PancakeSwapV3InvariantFuzzing --config echidna.yaml --test-limit 100000
```

## Understanding Results

### Successful Run
```
Analyzing contract: PancakeSwapV3InvariantFuzzing
Running 50000 tests...
assertion in fuzz_create_vault: PASSED
assertion in fuzz_deposit: PASSED
assertion in fuzz_withdraw: PASSED
assertion in fuzz_rebalance: PASSED
```

### Failed Assertion
```
assertion in fuzz_deposit: FAILED
Call sequence:
1. fuzz_create_vault(12345, 1000000000000000000000, 500000000000000000000, 3000)
2. fuzz_deposit(5000000000000000000000, 0)

Error: assertion failed at line 247
```

### Coverage Report
Coverage reports are generated in `test/echidna/fork-corpus/` directory:
- `covered.txt`: Text coverage report
- `coverage.html`: HTML coverage report (open in browser)

## Troubleshooting

### Common Issues

1. **"RPC URL not accessible"**
   - Ensure your `ALCHEMY_API_KEY` is set correctly
   - Check internet connection
   - Try a different RPC provider

2. **"Solc compilation failed"**
   - Ensure all dependencies are installed: `forge install`
   - Check Solidity version compatibility
   - Verify remappings in `echidna.yaml`

3. **"Contract not found"**
   - Ensure contract name matches: `PancakeSwapV3InvariantFuzzing`
   - Check file path in config
   - Verify contract compiles successfully

4. **"Assertion always fails"**
   - Check if test requires specific state setup
   - Verify fork state is correct at block 23225174
   - Review assertion logic

### Debug Mode
For detailed debugging, run with verbose output:
```bash
echidna . --contract PancakeSwapV3InvariantFuzzing --config echidna.yaml --debug
```

### Shrinking Failed Tests
When Echidna finds a failing assertion, it automatically tries to minimize the test case:
```bash
echidna . --contract PancakeSwapV3InvariantFuzzing --config echidna.yaml --shrink-limit 10000
```

## Customization

### Adding New Test Functions
1. Add function with `fuzz_` prefix
2. Use `require()` for preconditions
3. Use `assert()` for postconditions
4. Update ghost variables for state tracking

### Modifying Configuration
Edit `echidna.yaml` to adjust:
- Test limits and sequence lengths
- Fork block number
- Sender addresses
- Balance configurations

### Adding New Invariants
Add functions with `echidna_` prefix that return boolean:
```solidity
function echidna_my_invariant() public view returns (bool) {
    // Your invariant logic here
    return some_condition;
}
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Echidna Fuzzing
on: [push, pull_request]
jobs:
  fuzz:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          submodules: recursive
      - name: Install Echidna
        run: |
          curl -L https://github.com/crytic/echidna/releases/latest/download/echidna-2.2.1-Linux.tar.gz | tar -xz
          sudo mv echidna /usr/local/bin/
      - name: Run Echidna
        env:
          ALCHEMY_API_KEY: ${{ secrets.ALCHEMY_API_KEY }}
        run: ./run_echidna.sh
```

## Best Practices

1. **Start Simple**: Begin with basic invariants, add complexity gradually
2. **Use Ghost Variables**: Track state that should remain consistent
3. **Bound Inputs**: Always bound random inputs to reasonable ranges
4. **Handle Reverts**: Use try-catch for operations that may legitimately fail
5. **Fork Testing**: Use recent, stable block numbers for forking
6. **Regular Testing**: Run fuzzing regularly to catch regressions

## Further Reading

- [Echidna Documentation](https://github.com/crytic/echidna)
- [Property-Based Testing Guide](https://blog.trailofbits.com/2018/03/09/echidna-a-smart-fuzzer-for-ethereum/)
- [Foundry Book - Invariant Testing](https://book.getfoundry.sh/forge/invariant-testing)