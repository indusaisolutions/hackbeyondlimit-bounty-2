// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        address delegate;
        uint vote;
    }

    address public owner;
    uint public electionEndTime;
    uint public electionStartTime;
    bool public electionOngoing;
    mapping(address => Voter) public voters;
    mapping(uint => Candidate) public candidates;
    mapping(address => uint) public voterParticipation;
    uint public totalVoters;
    uint public totalCandidates;
    uint public totalVotes;
    uint public currentRound;
    mapping(uint => mapping(address => bool)) public roundVoters;
    mapping(uint => mapping(address => bool)) public roundVoted;
    mapping(uint => uint) public roundResults;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "You are not a registered voter");
        _;
    }

    modifier electionActive() {
        require(electionOngoing, "Election is not active");
        _;
    }

    modifier electionNotActive() {
        require(!electionOngoing, "Election is already active");
        _;
    }

    modifier electionNotEnded() {
        require(block.timestamp < electionEndTime, "Election has ended");
        _;
    }

    modifier electionEnded() {
        require(block.timestamp >= electionEndTime, "Election has not ended yet");
        _;
    }

    modifier hasNotVotedInCurrentRound() {
        require(!roundVoted[currentRound][msg.sender], "You have already voted in this round");
        _;
    }

    modifier isNotSelfDelegation(address _delegate) {
        require(_delegate != msg.sender, "You cannot delegate vote to yourself");
        _;
    }

    modifier validCandidate(uint _candidateId) {
        require(_candidateId > 0 && _candidateId <= totalCandidates, "Invalid candidate");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalVoters = 0;
        totalCandidates = 0;
        totalVotes = 0;
        electionOngoing = false;
        currentRound = 1;
    }

    function registerVoter(address _voter) external onlyOwner electionNotActive {
        require(!voters[_voter].isRegistered, "Voter is already registered");
        voters[_voter].isRegistered = true;
        totalVoters++;
    }

    function unregisterVoter(address _voter) external onlyOwner electionNotActive {
        require(voters[_voter].isRegistered, "Voter is not registered");
        voters[_voter].isRegistered = false;
        totalVoters--;
    }

    function addCandidate(string memory _name) external onlyOwner electionNotActive {
        totalCandidates++;
        candidates[totalCandidates] = Candidate({
            id: totalCandidates,
            name: _name,
            voteCount: 0
        });
    }

    function startElection(uint _duration) external onlyOwner electionNotActive {
        require(totalCandidates > 0, "At least one candidate is required");
        electionStartTime = block.timestamp;
        electionEndTime = block.timestamp + _duration;
        electionOngoing = true;
    }

    function endElection() external onlyOwner electionNotEnded {
        electionOngoing = false;
    }

    function delegateVote(address _to) external onlyRegisteredVoter electionActive isNotSelfDelegation(_to) {
        require(!voters[msg.sender].hasVoted, "You have already voted");
        require(voters[_to].isRegistered, "Delegate is not a registered voter");

        address currentDelegate = _to;
        while (voters[currentDelegate].delegate != address(0) && voters[currentDelegate].delegate != msg.sender) {
            currentDelegate = voters[currentDelegate].delegate;
        }

        require(currentDelegate != msg.sender, "Delegation loop detected");

        voters[msg.sender].delegate = _to;
        voterParticipation[msg.sender]++;
    }

    function vote(uint _candidateId) external onlyRegisteredVoter electionActive validCandidate(_candidateId) hasNotVotedInCurrentRound {
        require(voters[msg.sender].delegate == address(0), "You have delegated your vote");

        candidates[_candidateId].voteCount++;
        roundVoted[currentRound][msg.sender] = true;
        totalVotes++;
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].vote = _candidateId;
        roundResults[currentRound] = candidates[_candidateId].voteCount;
    }

    function voteInRound(uint _candidateId, uint _round) external onlyRegisteredVoter electionActive validCandidate(_candidateId) hasNotVotedInCurrentRound {
        require(_round == currentRound, "You can only vote in the current round");
        vote(_candidateId);
    }

    function nextRound() external onlyOwner electionActive {
        require(block.timestamp > electionEndTime, "Election has not ended");
        currentRound++;
        roundVoted[currentRound][msg.sender] = false;
    }

    function getResults(uint _round) external view returns (uint[] memory) {
        require(_round <= currentRound, "Results for future rounds are not available");

        uint[] memory results = new uint[](totalCandidates);
        for (uint i = 1; i <= totalCandidates; i++) {
            results[i-1] = candidates[i].voteCount;
        }
        return results;
    }

    function getCurrentRound() external view returns (uint) {
        return currentRound;
    }

    function getWinner(uint _round) external view returns (string memory) {
        require(_round <= currentRound, "Results for future rounds are not available");

        uint winningVoteCount = 0;
        uint winnerId;
        for (uint i = 1; i <= totalCandidates; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winnerId = i;
            }
        }

        return candidates[winnerId].name;
    }

    function getVoterParticipation(address _voter) external view returns (uint) {
        return voterParticipation[_voter];
    }

    function getElectionStatus() external view returns (bool) {
        return electionOngoing;
    }

    function getTimeRemaining() external view returns (uint) {
        if (block.timestamp < electionEndTime) {
            return electionEndTime - block.timestamp;
        } else {
            return 0;
        }
    }
}
