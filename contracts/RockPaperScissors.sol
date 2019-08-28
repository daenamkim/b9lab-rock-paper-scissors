pragma solidity 0.5.10;

import './Killable.sol';
import "./SafeMath.sol";

contract RockPaperScissors is Killable {
    using SafeMath for uint256;

    mapping(address => uint) public balances;
    mapping(address => uint) public rewards;
    mapping(address => uint) public commissions;

    uint commission = 1000;

    enum Choices { NotChosen, Rock, Paper, Scissors }
    struct Player {
        address addr;
        bytes32 moveHashed;
        Choices move;
    }
    struct Room {
        Player player1;
        Player player2;
    }
    Room gameRoom;

    event LogEnrolled(address indexed player, uint value, uint commission);
    event LogRefunded(address indexed player, uint value);
    event LogWithdrew(address indexed player, uint value);
    event LogOpened(address indexed player, Choices move);
    event LogPlayed(address indexed winner, uint valueRewarded);
    event LogCommissionSet(address indexed owner, uint newCommission);
    event LogCommissionCollectedWithdrew(address indexed owner, uint commissionCollected);

    function generateHash(Choices move, bytes32 secret) public view returns (bytes32) {
        require(move != Choices.NotChosen, "Should be chosen as the right");

        return keccak256(abi.encodePacked(move, secret, msg.sender, address(this)));
    }

    function enroll(bytes32 hashedMove) public payable whenNotPaused whenNotKilled returns (bool) {
        require(msg.value > commission, "Ether(wei) should be bigger than commission at least");

        uint finalValue = msg.value.sub(commission);
        address player1 = gameRoom.player1.addr;
        if (player1 == address(0)) {
            gameRoom.player1.addr = msg.sender;
            gameRoom.player1.moveHashed = hashedMove;
        } else if (gameRoom.player2.addr == address(0)) {
            require(msg.sender != player1, "A player2 should be different from a player1");
            require(finalValue >= balances[gameRoom.player1.addr], "A player2 bet same or greater money than player1 has");
            gameRoom.player2.addr = msg.sender;
            gameRoom.player2.moveHashed = hashedMove;
        } else {
            revert("A game room is full now");
        }

        address owner = getOwner();
        commissions[owner] = commissions[owner].add(commission);
        balances[msg.sender] = balances[msg.sender].add(finalValue);
        emit LogEnrolled(msg.sender, finalValue, commission);

        return true;
    }

    function open(bytes32 secret) public whenNotPaused whenNotKilled returns (bool) {
        bytes32 moveHashedPlayer1 = gameRoom.player1.moveHashed;
        bytes32 moveHashedPlayer2 = gameRoom.player2.moveHashed;
        require(moveHashedPlayer1 != bytes32(0) && moveHashedPlayer2 != bytes32(0), "All players should choose the move");

        Choices movePlayer1 = gameRoom.player1.move;
        Choices movePlayer2 = gameRoom.player2.move;
        require(
            movePlayer1 == Choices.NotChosen || movePlayer2 == Choices.NotChosen,
            "One player didn't open yet at least or game is not finished yet"
        );

        if (movePlayer1 == Choices.NotChosen) {
            if (moveHashedPlayer1 == generateHash(Choices.Rock, secret)) {
                gameRoom.player1.move = Choices.Rock;
                emit LogOpened(msg.sender, Choices.Rock);
            } else if (moveHashedPlayer1 == generateHash(Choices.Paper, secret)) {
                gameRoom.player1.move = Choices.Paper;
                emit LogOpened(msg.sender, Choices.Paper);
            } else if (moveHashedPlayer1 == generateHash(Choices.Scissors, secret)) {
                gameRoom.player1.move = Choices.Scissors;
                emit LogOpened(msg.sender, Choices.Scissors);
            }
        }

        if (movePlayer2 == Choices.NotChosen) {
            if (moveHashedPlayer2 == generateHash(Choices.Rock, secret)) {
                gameRoom.player2.move = Choices.Rock;
                emit LogOpened(msg.sender, Choices.Rock);
            } else if (moveHashedPlayer2 == generateHash(Choices.Paper, secret)) {
                gameRoom.player2.move = Choices.Paper;
                emit LogOpened(msg.sender, Choices.Paper);
            } else if (moveHashedPlayer2 == generateHash(Choices.Scissors, secret)) {
                gameRoom.player2.move = Choices.Scissors;
                emit LogOpened(msg.sender, Choices.Scissors);
            }
        }

        return true;
    }

    function play() public whenNotPaused whenNotKilled returns (bool) {
        Choices movePlayer1 = gameRoom.player1.move;
        Choices movePlayer2 = gameRoom.player2.move;
        require(movePlayer1 != Choices.NotChosen || movePlayer2 != Choices.NotChosen, "All players should open their moves");

        // Once result is draw, a user should deposit more ether to enroll next time. :)
        if ((movePlayer1 == Choices.Rock && movePlayer2 == Choices.Rock) ||
            (movePlayer1 == Choices.Paper && movePlayer2 == Choices.Paper) ||
            (movePlayer1 == Choices.Scissors && movePlayer2 == Choices.Scissors)) {
            emit LogPlayed(address(0), 0);

            reset();

            return true;
        }

        address player1 = gameRoom.player1.addr;
        address player2 = gameRoom.player2.addr;
        uint reward = balances[player1].add(balances[player2]);
        balances[player1] = 0;
        balances[player2] = 0;
        if ((movePlayer1 == Choices.Paper && movePlayer2 == Choices.Rock) ||
            (movePlayer1 == Choices.Scissors && movePlayer2 == Choices.Paper) ||
            (movePlayer1 == Choices.Rock && movePlayer2 == Choices.Scissors)) {
            rewards[player1] = rewards[player1].add(reward);
            emit LogPlayed(player1, reward);
        } else {
            rewards[player2] = rewards[player2].add(reward);
            emit LogPlayed(player2, reward);
        }

        reset();

        return true;
    }

    function reset() private {
        // Be a good citizen!
        delete gameRoom;
    }

    function refund() public whenNotPaused returns (bool) {
        uint value = balances[msg.sender];
        require(value > 0, "You did not enroll yet fot the game yet");

        emit LogRefunded(msg.sender, value);

        balances[msg.sender] = 0;
        msg.sender.transfer(value);

        return true;
    }

    function withdraw() public whenNotPaused returns (bool) {
        uint value = rewards[msg.sender];
        require(value > 0, "You have nothing to withdraw");

        emit LogWithdrew(msg.sender, value);

        rewards[msg.sender] = 0;
        msg.sender.transfer(value);

        return true;
    }

    function withdrawCommissionCollected() public returns (bool) {
        uint value = commissions[msg.sender];
        require(value > 0, "No commission collected to withdraw");

        emit LogCommissionCollectedWithdrew(msg.sender, value);

        commissions[msg.sender] = 0;
        msg.sender.transfer(value);

        return true;
    }

    function setCommission(uint newCommission) public onlyOwner whenNotKilled returns (bool) {
        commission = newCommission;

        emit LogCommissionSet(msg.sender, newCommission);

        return true;
    }
}
