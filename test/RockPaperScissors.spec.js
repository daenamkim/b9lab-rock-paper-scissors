const RockPaperScissors = artifacts.require('RockPaperScissors');
const truffleAssert = require('truffle-assertions');
const { toBN, toWei } = web3.utils;

const ROCK = 0;
const PAPER = 1;
const SCISSORS = 2;

contract('RockPaperScissors', function(accounts) {
  const [owner, alice, bob] = accounts;

  let rpsInstance;
  beforeEach(async () => {
    rpsInstance = await RockPaperScissors.new({ from: owner });
  });

  it('should avoid to enroll with insufficient value', async () => {
    await truffleAssert.fails(
      rpsInstance.enroll({
        from: alice,
        value: '10'
      }),
      'Enroll must at least 100 wei'
    );
  });

  it('should enroll successfully', async () => {
    const value = toWei('1', 'ether');
    const result = await rpsInstance.enroll({
      from: alice,
      value
    });
    assert.strictEqual(result.logs[0].event, 'LogEnrolled');
    assert.strictEqual(result.logs[0].args.player, alice);
    assert.strictEqual(result.logs[0].args.value.toString(), value);

    const playerAlice = await rpsInstance.players(alice);
    assert.strictEqual(playerAlice.toString(), value);
  });

  it('should avoid to refund for insufficient value', async () => {
    await truffleAssert.fails(
      rpsInstance.refund({ from: alice }),
      'You did not enroll yet fot the game yet'
    );
  });

  it('should refund successfully', async () => {
    const value = toWei('1', 'ether');
    await rpsInstance.enroll({
      from: alice,
      value
    });

    const balanceBefore = await web3.eth.getBalance(alice);
    const result = await rpsInstance.refund({ from: alice });
    assert.strictEqual(result.logs[0].event, 'LogRefunded');
    assert.strictEqual(result.logs[0].args.player, alice);
    assert.strictEqual(result.logs[0].args.value.toString(), value);

    const gasPrice = await web3.eth.getGasPrice();
    const amountGasUsed = toBN(result.receipt.gasUsed).mul(toBN(gasPrice));
    const balanceAfter = await web3.eth.getBalance(alice);
    assert.strictEqual(
      toBN(balanceAfter).toString(),
      toBN(balanceBefore)
        .add(toBN(value))
        .sub(amountGasUsed)
        .toString()
    );
  });

  it('should avoid to play with insufficient values', async () => {
    await truffleAssert.fails(
      rpsInstance.play(alice, ROCK, bob, ROCK, { from: owner }),
      'Each player must bet at least 100 wei before play'
    );
  });

  it('should play successfully', async () => {
    const value = toWei('1', 'ether');
    await rpsInstance.enroll({ from: alice, value });
    await rpsInstance.enroll({ from: bob, value });

    // Draw
    let result = await rpsInstance.play(alice, ROCK, bob, ROCK, {
      from: owner
    });
    assert.strictEqual(result.logs[0].event, 'LogPlayed');
    assert.strictEqual(
      result.logs[0].args.winner,
      '0x0000000000000000000000000000000000000000'
    );
    assert.strictEqual(result.logs[0].args.valueRewarded.toString(), '0');

    // Winner is Alice
    result = await rpsInstance.play(alice, PAPER, bob, ROCK, {
      from: owner
    });
    assert.strictEqual(result.logs[0].event, 'LogPlayed');
    assert.strictEqual(result.logs[0].args.winner, alice);
    assert.strictEqual(
      result.logs[0].args.valueRewarded.toString(),
      toBN(value)
        .add(toBN(value))
        .toString()
    );
    let winner = await rpsInstance.winners(alice);
    assert.strictEqual(
      toBN(winner).toString(),
      toBN(value)
        .add(toBN(value))
        .toString()
    );

    // Winner is Bob
    await rpsInstance.enroll({ from: alice, value });
    await rpsInstance.enroll({ from: bob, value });

    result = await rpsInstance.play(alice, SCISSORS, bob, ROCK, {
      from: owner
    });
    assert.strictEqual(result.logs[0].event, 'LogPlayed');
    assert.strictEqual(result.logs[0].args.winner, bob);
    assert.strictEqual(
      result.logs[0].args.valueRewarded.toString(),
      toBN(value)
        .add(toBN(value))
        .toString()
    );
    winner = await rpsInstance.winners(bob);
    assert.strictEqual(
      toBN(winner).toString(),
      toBN(value)
        .add(toBN(value))
        .toString()
    );
  });

  it('should avoid to withdraw for insufficient value', async () => {
    await truffleAssert.fails(
      rpsInstance.withdraw({ from: alice }),
      'You have nothing to withdraw'
    );
  });

  it('should withdraw successfully', async () => {
    const value = toWei('1', 'ether');
    await rpsInstance.enroll({ from: alice, value });
    await rpsInstance.enroll({ from: bob, value });
    await rpsInstance.play(alice, PAPER, bob, ROCK, {
      from: owner
    });
    const balanceBefore = await web3.eth.getBalance(alice);
    const result = await rpsInstance.withdraw({ from: alice });
    assert.strictEqual(result.logs[0].event, 'LogWithdrew');
    assert.strictEqual(result.logs[0].args.player, alice);

    const reward = result.logs[0].args.value;
    assert.strictEqual(
      reward.toString(),
      toBN(value)
        .add(toBN(value))
        .toString()
    );

    const gasPrice = await web3.eth.getGasPrice();
    const amountGasUsed = toBN(result.receipt.gasUsed).mul(toBN(gasPrice));
    const balanceAfter = await web3.eth.getBalance(alice);
    assert.strictEqual(
      toBN(balanceAfter).toString(),
      toBN(balanceBefore)
        .add(reward)
        .sub(amountGasUsed)
        .toString()
    );
  });
});
