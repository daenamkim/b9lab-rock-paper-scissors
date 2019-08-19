const RockPaperScissors = artifacts.require('RockPaperScissors');
const truffleAssert = require('truffle-assertions');
const { toBN, toWei } = web3.utils;

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

    const playerAlice = await rpsInstance.players(alice, {
      from: alice
    });
    assert.strictEqual(playerAlice.toString(), toWei('1', 'ether'));
  });
});
