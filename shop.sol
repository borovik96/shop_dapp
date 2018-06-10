pragma solidity ^0.4.21;

contract Ownable {
  address owner;
  mapping (address => bool) administrators;

  function Ownable() {
    require(owner == 0);
    msg.sender = owner;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
}

contract Shop is Ownable{
  struct trade {
    address sellerAddr;
    bytes32 sigSeller;
    bytes32 sigBuyer;
    bytes32 dataHash;
    uint sum;
  }
  mapping (bytes32 => trade) trades;
  uint commission = 10; // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
  uint commissionAmount; // размер доступных для вывода средств в wei

  event Trade();

  function Shop(address[] _administrators) {
    for(uint i = 0; i < _administrators.length(); i++) {
      administrators[_administrators[i]] = true;
    }
    administrators[owner] = true;
  }

  function initiateTrade(
    address sellerAddr,
    bytes32 sigSeller,
    bytes32 sigBuyer,
    bytes32 dataHash,
    uint sum
   ) {

  }

  function resolveTrade(bytes32 tradeId) {

  }

  function rejectTrade(bytes32 tradeId) {

  }

  function withdrawCommission(address destination) onlyOwner {
    destination.transfer(commissionAmount);
    commissionAmount = 0;
  }

  function setCommission(uint _commission) { // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
    require(_commission > 0);
    commission = _commission;
  }

  function getCommissionAmount() onlyOwner {
    return commissionAmount;
  }

  function addAdministrator(address _administrator) onlyOwner {
    require(!administrators[_administrator]);
    administrators[_administrator] = true;
  }

  function deleteAdminitstrator(address _administrator) onlyOwner {
    require(administrators[_administrator]);
    administrators[_administrator] = false;
  }
}
