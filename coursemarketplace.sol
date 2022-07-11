// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";

contract CourseMarketplace {

  using Counters for Counters.Counter;
  Counters.Counter private _courseId;

  enum State {
    Purchased,
    Activated,
    Deactivated
  }

  struct Course {
    uint id; // 32
    uint price; // 32
    bytes32 proof; // 32
    address owner; // 20
    State state; // 1
  }

  bool public isStopped = false;

  // mapping of courseHash to Course data
  mapping(bytes32 => Course) private ownedCourses;

  // mapping of courseID to courseHash
  mapping(uint => bytes32) private ownedCourseHash;

  // number of all courses + id of the course
  uint private totalOwnedCourses;

  address payable private owner;

  constructor() {
    setContractOwner(msg.sender);
  }

  /// Course has invalid state!
  error InvalidState();

  /// Course is not created!
  error CourseIsNotCreated();

  /// Course has already a Owner!
  error CourseHasOwner();

  /// Sender is not course owner!
  error SenderIsNotCourseOwner();

  /// Only owner has an access!
  error OnlyOwner();

  modifier onlyOwner() {
    if (msg.sender != getContractOwner()) {
      revert OnlyOwner();
    }
    _;
  }

  modifier onlyWhenNotStopped {
    require(!isStopped);
    _;
  }

  modifier onlyWhenStopped {
    require(isStopped);
    _;
  }

  receive() external payable {}

  // withdraw some amount from contract
  function withdraw(uint amount)
    external
    onlyOwner
  {
    require(amount <= address(this).balance, "not enough ethers to withdraw");
    (bool success, ) = owner.call{value: amount}("");
    require(success, "Transfer failed.");
  }

  // withdraw all amount from contract
  function emergencyWithdraw()
    external
    onlyWhenStopped
    onlyOwner
  {
    require(address(this).balance > 0, "not enough ethers to withdraw");
    (bool success, ) = owner.call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  // destroy contract
  function selfDestruct()
    external
    onlyWhenStopped
    onlyOwner
  {
    selfdestruct(owner);
  }

  // pause contract execution
  function stopContract()
    external
    onlyOwner
  {
    isStopped = true;
  }

  // resume contract execution
  function resumeContract()
    external
    onlyOwner
  {
    isStopped = false;
  }

  // purchase a new course 
  function purchaseCourse(
    bytes16 courseId, // 0x00000000000000000000000000003130
    bytes32 proof // 0x0000000000000000000000000000313000000000000000000000000000003130
  )
    external
    payable
    onlyWhenNotStopped
  {    
    bytes32 courseHash = keccak256(abi.encodePacked(courseId, msg.sender));

    if (hasCourseOwnership(courseHash)) {
      revert CourseHasOwner();
    }
    Course storage course = ownedCourses[courseHash];
    address payable seller = payable(course.owner);
    require(msg.value >= course.price, "ether sent too low for course price");
    require(proof == course.proof, "invalid proof");
    course.state = State.Purchased;
    course.owner = msg.sender;

    (bool sent, ) = seller.call{value: msg.value}("");
    require(sent, "sent unsuccessful");
   
  }

  function createCourse(bytes32 proof, uint256 price) public {

    uint256 courseId = _courseId.current();
    _courseId.increment();

    bytes32 courseHash = keccak256(abi.encodePacked(courseId, msg.sender));

    if (hasCourseOwnership(courseHash)) {
      revert CourseHasOwner();
    }

    ownedCourseHash[courseId] = courseHash;
    ownedCourses[courseHash] = Course({
      id: courseId,
      price: price,
      proof: proof,
      owner: msg.sender,
      state: State.Purchased
    });
  }

  // re-purchase a course
  function repurchaseCourse(bytes32 courseHash)
    external
    payable
    onlyWhenNotStopped
  {
    if (!isCourseCreated(courseHash)) {
      revert CourseIsNotCreated();
    }

    if (!hasCourseOwnership(courseHash)) {
      revert SenderIsNotCourseOwner();
    }

    Course storage course = ownedCourses[courseHash];

    if (course.state != State.Deactivated) {
      revert InvalidState();
    }

    course.state = State.Purchased;
    course.price = msg.value;
  }

  // activate  a course
  function activateCourse(bytes32 courseHash)
    external
    onlyWhenNotStopped
    onlyOwner
  {
    if (!isCourseCreated(courseHash)) {
      revert CourseIsNotCreated();
    }

    Course storage course = ownedCourses[courseHash];

    if (course.state != State.Purchased) {
      revert InvalidState();
    }

    course.state = State.Activated;
  }

  // deactivate a course
  function deactivateCourse(bytes32 courseHash)
    external
    onlyWhenNotStopped
    onlyOwner
  {
    if (!isCourseCreated(courseHash)) {
      revert CourseIsNotCreated();
    }

    Course storage course = ownedCourses[courseHash];

    if (course.state != State.Purchased) {
      revert InvalidState();
    }

    course.state = State.Deactivated;
    course.price = 0;

    (bool success, ) = course.owner.call{value: course.price}("");
    require(success, "Transfer failed!");   
  }

  // transfer owner of contract to new owner
  function transferOwnership(address newOwner)
    external
    onlyOwner
  {
    setContractOwner(newOwner);
  }

  // get total number of course created
  function getCourseCount()
    external
    view
    returns (uint)
  {
    return totalOwnedCourses;
  }

  // get hash index of a course
  function getCourseHashAtIndex(uint index)
    external
    view
    returns (bytes32)
  {
    return ownedCourseHash[index];
  }

  // get course by it's hash
  function getCourseByHash(bytes32 courseHash)
    external
    view
    returns (Course memory)
  {
    return ownedCourses[courseHash];
  }

  // get owner of contract
  function getContractOwner()
    public
    view
    returns (address)
  {
    return owner;
  }

  // set new contract owner
  function setContractOwner(address newOwner) private {
    owner = payable(newOwner);
  }

  // check if course is created
  function isCourseCreated(bytes32 courseHash)
    private
    view
    returns (bool)
  {
    return ownedCourses[courseHash].owner != address(0);
  }

  // check if msg.sender owns course
  function hasCourseOwnership(bytes32 courseHash)
    private
    view
    returns (bool)
  {
    return ownedCourses[courseHash].owner == msg.sender;
  }
}
