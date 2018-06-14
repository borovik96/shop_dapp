pragma solidity ^0.4.21;
import "./SafeMath.sol";
import "./strings.sol";

contract Ownable {
  address owner;
  mapping (address => bool) administrators;

  constructor() public {
    require(owner == 0);
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  modifier onlyAdministrator() {
    require(administrators[msg.sender]);
    _;
  }
}

contract Shop is Ownable{
  using strings for *;
  using SafeMath for uint;
  struct Trade {
    address sellerAddr;
    address buyerAddr;
    bytes32 dataHash;
    uint sum;
  }
  mapping (bytes32 => Trade) trades;
  uint commission = 10; // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
  uint commissionAmount; // размер доступных для вывода средств в wei

  event InitiateTrade(address sellerAddr, address buyerAddr, bytes32 dataHash, uint sum);
  event ResolveTrade(bytes32 tradeId, address sellerAddr, uint amount);
  event RejectTrade(bytes32 tradeId, address buyerAddr, uint amount);

  constructor(address[] _administrators) public{
    for(uint i = 0; i < _administrators.length; i++) {
      administrators[_administrators[i]] = true;
    }
    administrators[owner] = true;
  }

  function initiateTrade(
    address _sellerAddr,
    uint _vSeller,
    bytes32 _rSeller,
    bytes32 _sSeller,
    uint _vBuyer,
    bytes32 _rBuyer,
    bytes32 _sBuyer,
    bytes32 _dataHash,
    uint _sum
   ) payable public {
     require(msg.value == _sum);
     bytes32[] memory req = new bytes32[](3);
     req[0] = _dataHash;
     req[1] = bytes32(_sum);
     req[2] = bytes32(_sellerAddr);
     string memory s = bytes32ArrayToString(req);
     bytes32 __dataHash = stringToBytes32(s);
     require(ecrecover(__dataHash, uint8(_vSeller), _rSeller, _sSeller) == _sellerAddr); // проверяем корректность подписи продавца
     require(ecrecover(_dataHash, uint8(_vBuyer), _rBuyer, _sBuyer) == msg.sender); // проверяем корректность подписи покупателя
     require(trades[_dataHash].dataHash == 0);
     Trade memory trade = Trade(_sellerAddr, msg.sender, _dataHash, _sum);
     trades[_dataHash] = trade;
     emit InitiateTrade(_sellerAddr, msg.sender, _dataHash, _sum);
  }

  function resolveTrade(bytes32 tradeId) public onlyAdministrator {
    Trade memory trade = trades[tradeId];
    uint _amountCommission = trade.sum;
    _amountCommission = _amountCommission.div(10000).mul(commission); // 10000, т.к. комиссия хранится не в процентах (100% * 100)
    uint amount = trade.sum.sub(_amountCommission);
    address _sellerAddr = trade.sellerAddr;
    commissionAmount = commissionAmount.add(_amountCommission);
    _sellerAddr.transfer(amount);
    delete(trades[tradeId]);
    emit ResolveTrade(tradeId, _sellerAddr, amount);
  }

  function rejectTrade(bytes32 tradeId) public onlyAdministrator {
    Trade memory trade = trades[tradeId];
    uint amount = trade.sum;
    address _buyerAddr = trade.buyerAddr;
    _buyerAddr.transfer(amount);
    delete(trades[tradeId]);
    emit RejectTrade(tradeId, _buyerAddr, amount);
  }

  function withdrawCommission(address destination) public onlyOwner {
    destination.transfer(commissionAmount);
    commissionAmount = 0;
  }

  function setCommission(uint _commission) onlyOwner public { // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
    require(_commission > 0);
    commission = _commission;
  }

  function getCommissionAmount() public onlyOwner view returns(uint){
    return commissionAmount;
  }

  function addAdministrator(address _administrator) public onlyOwner {
    require(!administrators[_administrator]);
    administrators[_administrator] = true;
  }

  function deleteAdminitstrator(address _administrator) public onlyOwner {
    require(administrators[_administrator]);
    administrators[_administrator] = false;
  }

  function isAdministrator(address addr) public onlyOwner view returns(bool) {
    return administrators[addr];
  }

    function bytes32ArrayToString (bytes32[] data) internal pure returns (string) {
    bytes memory bytesString = new bytes(data.length * 32);
    uint urlLength;
    for (uint i=0; i<data.length; i++) {
        for (uint j=0; j<32; j++) {
            byte char = byte(bytes32(uint(data[i]) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[urlLength] = char;
                urlLength += 1;
            }
        }
    }
    bytes memory bytesStringTrimmed = new bytes(urlLength);
    for (i=0; i<urlLength; i++) {
        bytesStringTrimmed[i] = bytesString[i];
    }
    return string(bytesStringTrimmed);
    }

    function toString(address x) returns (string) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++)
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        return string(b);
    }

    function stringToBytes32(string memory source) returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }

    assembly {
        result := mload(add(source, 32))
    }
}
}
