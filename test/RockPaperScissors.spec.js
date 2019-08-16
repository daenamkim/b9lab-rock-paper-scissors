var RockPaperScissors = artifacts.require("RockPaperScissors");

contract("RockPaperScissors", function(accounts) {
  it("should assert true", function(done) {
    var rock_paper_scissors = RockPaperScissors.deployed();
    assert.isTrue(true);
    done();
  });
});
