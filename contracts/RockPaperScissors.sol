pragma solidity 0.5.10;

import './Killable.sol';
import "./SafeMath.sol";

contract RockPaperScissors is Killable {
    using SafeMath for uint256;

    mapping(address => uint) public players;
    mapping(address => uint) public winners;

    enum Choices { Rock, Paper, Scissors }

    event LogEnrolled(address indexed player, uint value);
    event LogRefunded(address indexed player, uint value);
    event LogWithdrew(address indexed player, uint value);
    event LogPlayed(address indexed winner, uint valueRewarded);

    function enrol() public payable whenNotPaused whenNotKilled returns (bool) {
        require(players[msg.sender] == 0, "You cannot enroll more than once until the game is done");
        require(msg.value >= 100, "Enroll must at least 100 wei");

        players[msg.sender] = msg.value;

        emit LogEnrolled(msg.sender, msg.value);

        return true;
    }

    // Only owner can call this passing two players choices from the app.
    // Onwer can be a system with private key outside of blockchain.
    // And owner doesn't have any profit so players might need to pay some commission per game to the owner.
    function play(address p1, Choices choiceP1, address p2, Choices choiceP2)
        public
        onlyOwner
        whenNotPaused
        whenNotKilled
        returns (bool) {

        uint valueP1 = players[p1];
        uint valueP2 = players[p2];
        require(valueP1 >= 100 && valueP2 >= 100, "Each player must bet at least 100 wei before play");

        if ((choiceP1 == Choices.Rock && choiceP2 == Choices.Rock) ||
            (choiceP1 == Choices.Paper && choiceP2 == Choices.Paper) ||
            (choiceP1 == Choices.Scissors && choiceP2 == Choices.Scissors)) {
            emit LogPlayed(address(0), 0);
        } else if ((choiceP1 == Choices.Paper && choiceP2 == Choices.Rock) ||
            (choiceP1 == Choices.Scissors && choiceP2 == Choices.Paper) ||
            (choiceP1 == Choices.Rock && choiceP2 == Choices.Scissors)) {
            uint reward = valueP1.add(valueP2);
            winners[p1] = winners[p1].add(reward);
            players[p1] = 0;
            players[p2] = 0;

            emit LogPlayed(p1, reward);
        } else {
            uint reward = valueP1.add(valueP2);
            winners[p2] = winners[p2].add(reward);
            players[p1] = 0;
            players[p2] = 0;

            emit LogPlayed(p2, reward);
        }

        return true;
    }

    function refund() public whenNotPaused returns (bool) {
        uint value = players[msg.sender];
        require(value > 0, "You did not enroll yet fot the game yet");

        emit LogRefunded(msg.sender, value);

        players[msg.sender] = 0;
        msg.sender.transfer(value);

        return true;
    }

    function withdraw() public whenNotPaused returns (bool) {
        uint value = winners[msg.sender];
        require(value > 0, "You have nothing to withdraw");

        emit LogWithdrew(msg.sender, value);

        winners[msg.sender] = 0;
        msg.sender.transfer(value);

        return true;
    }
}
