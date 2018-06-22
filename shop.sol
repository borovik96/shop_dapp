pragma solidity ^0.4.21;
import "./SafeMath.sol";
import "./strings.sol";

contract Ownable { // Базовый контракт, обеспечивающий разграничение доступа
  address owner;
  mapping (address => bool) administrators;

  constructor() public {
    require(owner == 0);
    owner = msg.sender;
  }

  modifier onlyOwner() { // модификатор, Обеспечивающий возможность вызова функций только владельцем
    require(msg.sender == owner);
    _;
  }

  modifier onlyAdministrator() { // модификатор, Обеспечивающий возможность вызова функций только администратором
    require(administrators[msg.sender]);
    _;
  }
}

contract Shop is Ownable { // основной контракт
  using strings for *; // инициализация библиотек
  using SafeMath for uint;
  struct Trade { // струкутра, хранящая в себе сделку
    address sellerAddr;
    address buyerAddr;
    bytes32 dataHash;
    uint sum;
  }
  mapping (bytes32 => Trade) trades;
  uint commission = 10; // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
  uint commissionAmount; // размер доступных для вывода средств в wei

  // События вызываются для оповещения сервера
  event InitiateTrade(address sellerAddr, address buyerAddr, bytes32 dataHash, uint sum);
  event ResolveTrade(bytes32 tradeId, address sellerAddr, uint amount);
  event RejectTrade(bytes32 tradeId, address buyerAddr, uint amount);

  constructor(address[] _administrators) public {
    for(uint i = 0; i < _administrators.length; i++) { // инициализация администраторов
      administrators[_administrators[i]] = true;
    }
    administrators[owner] = true; // default: owner = admin
  }

  function initiateTrade( // функция для создания сделки
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
     require(msg.value == _sum); // Нужна ли возможность присылать больше eth? Разницу вернем
     // Приведение типов для проверки подписи (***ц какой-то)
     bytes32[] memory req = new bytes32[](3);
     req[0] = _dataHash;
     req[1] = bytes32(_sum);
     req[2] = bytes32(_sellerAddr);
     string memory s = bytes32ArrayToString(req);
     bytes32 __dataHash = stringToBytes32(s);

     require(ecrecover(__dataHash, uint8(_vSeller), _rSeller, _sSeller) == _sellerAddr); // проверяем корректность подписи продавца
     require(ecrecover(_dataHash, uint8(_vBuyer), _rBuyer, _sBuyer) == msg.sender); // проверяем корректность подписи покупателя
     require(trades[_dataHash].dataHash == 0); // проверяем, что сделки еще не существует
     Trade memory trade = Trade(_sellerAddr, msg.sender, _dataHash, _sum); // инициализация сделки
     trades[_dataHash] = trade;
     emit InitiateTrade(_sellerAddr, msg.sender, _dataHash, _sum); // оповещение эвентом
  }

  function resolveTrade(bytes32 tradeId) public onlyAdministrator { // при вызове функции деньги перечисляются продавцу
    Trade memory trade = trades[tradeId];
    // вычисление комиссии сервиса
    uint _amountCommission = trade.sum;
    _amountCommission = _amountCommission.div(10000).mul(commission); // 10000, т.к. комиссия хранится не в процентах (100% * 100)
    uint amount = trade.sum.sub(_amountCommission);
    address _sellerAddr = trade.sellerAddr;
    commissionAmount = commissionAmount.add(_amountCommission);

    // трансфер денег продавцу и удаление сделки
    _sellerAddr.transfer(amount);
    delete(trades[tradeId]);
    emit ResolveTrade(tradeId, _sellerAddr, amount);
  }

  function rejectTrade(bytes32 tradeId) public onlyAdministrator { // при вызове функции деньги перечисляются покупателю, сделка неуспешна
    Trade memory trade = trades[tradeId];
    uint amount = trade.sum;
    address _buyerAddr = trade.buyerAddr;
    // перечисляем деньги обратно покупателю и удаляем сделку
    _buyerAddr.transfer(amount);
    delete(trades[tradeId]);
    emit RejectTrade(tradeId, _buyerAddr, amount);
  }

  function withdrawCommission(address destination) public onlyOwner { // Вывод собранной комиссии на переданный адрес
    destination.transfer(commissionAmount);
    commissionAmount = 0;
  }

  function setCommission(uint _commission) onlyOwner public { // комиссия в %, умноженной на 100, например чтобы выставить комиссию 0.01% - указываем "1"
    require(_commission > 0);
    commission = _commission;
  }

  function getCommissionAmount() public onlyOwner view returns(uint) { // доступные для вывода средства
    return commissionAmount;
  }

  function addAdministrator(address _administrator) public onlyOwner { // добавление администратора
    require(!administrators[_administrator]);
    administrators[_administrator] = true;
  }

  function deleteAdminitstrator(address _administrator) public onlyOwner { // удаление администратора
    require(administrators[_administrator]);
    administrators[_administrator] = false;
  }

  function isAdministrator(address addr) public onlyOwner view returns(bool) { // проверка на администратора
    return administrators[addr];
  }

  function bytes32ArrayToString (bytes32[] data) internal pure returns (string) { // вспомогательная функция
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

  function toString(address x) internal pure returns (string) { // вспомогательная функция
    bytes memory b = new bytes(20);
    for (uint i = 0; i < 20; i++)
        b[i] = byte(uint8(uint(x) / (2**(8*(19 - i))))); // magic code
    return string(b);
  }

  function stringToBytes32(string memory source) internal pure returns (bytes32 result) { // вспомогательная функция
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }
    assembly {
        result := mload(add(source, 32)) // добавим немного магии и все будет работать
    }
  }
}
