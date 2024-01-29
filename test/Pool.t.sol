// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Pool} from "../src/Pool.sol";

contract PoolTest is Test {
    address owner = makeAddr("owner");
    address userA = makeAddr("user a");
    address userB = makeAddr("user b");
    address userC = makeAddr("user c");

    uint256 duration = 4 weeks; // timestamp 4 * 7 * 24 * 3600
    uint256 goal = 10 ether;
    uint256 contributions = 2 ether;

    Pool pool;

    function setUp() public {
        vm.prank(owner);
        pool = new Pool(duration, goal);
    }

    // Deploy contract
    function test_ContractDeployedSuccessful() public {
        address _owner = pool.owner();
        assertEq(owner, _owner);

        uint256 _end = pool.end();
        assertEq(block.timestamp + duration, _end);

        uint256 _goal = pool.goal();
        assertEq(goal, _goal);
    }

    // Test contribute()
    function test_RevertWhen_EndIsReached() public {
        vm.warp(pool.end() + 3600);

        bytes4 selector = bytes4(keccak256("CollectIsFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(userA);
        vm.deal(userA, 1 ether);
        pool.contribute{value: 0.1 ether}();
    }

    function test_RevertWhen_NotEnoughFunds() public {
        bytes4 selector = bytes4(keccak256("NotEnoughFunds()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(userA);
        pool.contribute();
    }

    function test_ExpectEmitSuccessfulContribute(uint96 _amount) public {
        vm.assume(_amount > 0);
        vm.expectEmit(true, false, false, true);
        emit Pool.Contribute(address(userA), _amount);

        vm.prank(userA);
        vm.deal(userA, _amount);
        pool.contribute{value: _amount}();
    }

    // Test withdraw()
    function test_RevertWhen_NotTheOwner() public {
        bytes4 selector = bytes4(
            keccak256("OwnableUnauthorizedAccount(address)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, userA));

        vm.prank(userA);
        pool.withdraw();
    }

    function test_RevertWhen_EndIsNotReached() public {
        bytes4 selector = bytes4(keccak256("CollectNotFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(owner);
        pool.withdraw();
    }

    function test_RevertWhen_GoalIsNotReached() public {
        vm.prank(userA);
        vm.deal(userA, 5 ether);
        pool.contribute{value: 5 ether}();

        vm.warp(pool.end() + 3600);
        bytes4 selector = bytes4(keccak256("CollectNotFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(owner);
        pool.withdraw();
    }

    function testRevertWhen_WithdrawFailedToSendEther() public {
        // PoolTest contract is owner of Pool contract
        pool = new Pool(duration, goal);

        // Case where CollectIsNotFinished() isn't called,
        // meaning the transaction should be valid
        // (block.timestamp > end || totalCollected > goal)
        vm.prank(userA);
        vm.deal(userA, 6 ether);
        pool.contribute{value: 6 ether}();

        vm.prank(userB);
        vm.deal(userB, 5 ether);
        pool.contribute{value: 5 ether}();

        vm.warp(pool.end() + 3600);
        bytes4 selector = bytes4(keccak256("FailedToSendEther()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        // But reverts and calls FailedToSendEther() because PoolTest is owner of Pool,
        // and has no receiver(), or fallback() functions

        pool.withdraw();
    }

    function test_Withdraw() public {
        vm.prank(userA);
        vm.deal(userA, 6 ether);
        pool.contribute{value: 6 ether}();

        vm.prank(userB);
        vm.deal(userB, 5 ether);
        pool.contribute{value: 5 ether}();

        vm.warp(pool.end() + 3600);

        vm.prank(owner);
        pool.withdraw();
    }

    // Test refund()
    function test_RevertWhen_CollectNotFinished() public {
        vm.prank(userA);
        vm.deal(userA, 6 ether);
        pool.contribute{value: 6 ether}();

        vm.prank(userB);
        vm.deal(userB, 5 ether);
        pool.contribute{value: 5 ether}();

        bytes4 selector = bytes4(keccak256("CollectNotFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(userA);
        pool.refund();
    }

    function test_RevertWhen_GoalAlreadyReached() public {
        vm.prank(userA);
        vm.deal(userA, 6 ether);
        pool.contribute{value: 6 ether}();

        vm.prank(userB);
        vm.deal(userB, 5 ether);
        pool.contribute{value: 5 ether}();

        vm.warp(pool.end() + 3600);

        bytes4 selector = bytes4(keccak256("GoalAlreadyReached()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(userA);
        pool.refund();
    }

    function test_RevertWhen_NoContribution() public {
        vm.prank(userA);
        vm.deal(userA, 6 ether);
        pool.contribute{value: 6 ether}();

        vm.prank(userB);
        vm.deal(userB, 1 ether);
        pool.contribute{value: 1 ether}();

        vm.warp(pool.end() + 3600);

        bytes4 selector = bytes4(keccak256("NoContribution()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(userC);
        pool.refund();
    }

    function test_RevertWhen_RefundFailedToSendEther() public {
        // It doesn't need to be the owner, so no call of the Pool contract is needed
        vm.deal(address(this), 2 ether);
        pool.contribute{value: 2 ether}();

        vm.prank(userA);
        vm.deal(userA, 6 ether);
        pool.contribute{value: 6 ether}();

        vm.warp(pool.end() + 3600);

        bytes4 selector = bytes4(keccak256("FailedToSendEther()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        pool.refund();
    }

    function test_Refund() public {
        uint256 amountToFund = 1 ether;

        vm.prank(userA);
        vm.deal(userA, 6 ether);
        pool.contribute{value: 6 ether}();

        vm.prank(userB);
        vm.deal(userB, 1 ether);
        pool.contribute{value: amountToFund}(); // Goal not reached

        vm.warp(pool.end() + 3600);

        uint256 balanceBeforeRefund = userB.balance;

        vm.prank(userB); // Test userB with AmountToFund
        pool.refund();

        uint256 balanceAfterRefund = userB.balance;

        assertEq(balanceBeforeRefund + amountToFund, balanceAfterRefund);
    }
}
