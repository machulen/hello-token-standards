// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ERC20 {
    function name() external view returns (string calldata);
    function symbol() external view returns (string calldata);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Pie is ERC20 {
    string constant public override name = "Pie";
    string constant public override symbol = "PIE";
    uint8 constant public override decimals = 18;
    uint256 public override totalSupply = 0;
    uint256 constant public maxSupply = 1e21;
    uint256 constant public maxBakers = 3;
    uint256 constant public maxPiesPerHour = 4e18;
    address public chef;
    address[maxBakers] public bakers;
    bool public isKitchenOpen = true;

    event bakerHired(address _baker);
    event bakerFired(address _baker);
    event chefChanged(address _newChef);
    event kitchenOpen();
    event kitchenClosed();

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => uint256) private _piesThisHour; // pies baked or burned this hour
    mapping (address => uint256) private _lastActionTimestamp;

    constructor() {
        chef = msg.sender;
    }

    function balanceOf(address _owner) external view override returns (uint256 balance) {
        return _balances[_owner];
    }

    function transfer(address _to, uint256 _value) external override returns (bool success) {
        require(_balances[msg.sender] >= _value, "Insufficient balance");
        _balances[msg.sender] -= _value;
        _balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external override returns (bool success) {
        require(_balances[_from] >= _value, "Insufficient balance");
        require(_allowances[_from][msg.sender] >= _value, "Insufficient allowance");
        _balances[_from] -= _value;
        _balances[_to] += _value;
        _allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        emit Approval(_from, msg.sender, _allowances[_from][msg.sender]);
        return true;
    }

    function approve(address _spender, uint256 _value) external override returns (bool success) {
        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }

    modifier onlyChef() {
        require(msg.sender == chef, "Permission denied - only Chef is allowed to use this function");
        _;
    }

    modifier onlyBaker() {
        for (uint i = 0; i < maxBakers; i++) {
            if (msg.sender == bakers[i]) {
                _;
                return;
            }
        }
        revert("Permission denied - only a baker is allowed to use this function");
    }

    function changeChef(address _newChef) external onlyChef returns (bool success) {
        chef = _newChef;
        emit chefChanged(_newChef);
        return true;
    }

    function openKitchen() external onlyChef returns (bool success) {
        isKitchenOpen = true;
        emit kitchenOpen();
        return true;
    }

    function closeKitchen() external onlyChef returns (bool success) {
        isKitchenOpen = false;
        emit kitchenClosed();
        return true;
    }

    function hireBaker(address _baker) external onlyChef returns (bool success) {
        for (uint i = 0; i < maxBakers; i++) {
            if (bakers[i] == address(0)) {
                bakers[i] = _baker;
                emit bakerHired(_baker);
                return true;
            }
        }
        revert("Can't hire a baker - no vacancies left");
    }

    function fireBaker(address _baker) external onlyChef returns (bool success) {
        for (uint i = 0; i < maxBakers; i++) {
            if (bakers[i] == _baker) {
                bakers[i] = address(0);
                emit bakerFired(_baker);
                return true;
            }
        }
        revert("There is no such baker");
    }

    function debug() external view returns (uint, uint) {
        return (block.timestamp / 1 hours, _lastActionTimestamp[msg.sender] / 1 hours);
    }

    // Each baker can either issue or burn 4 pies per 1 hour (this value is stored as maxPiesPerHour)
    function _ensureHourLimitForBakers(uint _amount) private {
        if (block.timestamp / 1 hours == _lastActionTimestamp[msg.sender] / 1 hours) {
            require(_piesThisHour[msg.sender] < maxPiesPerHour,
                "Your pie limit exceeded - you can't bake or burn pies till next hour");
            require(_piesThisHour[msg.sender] + _amount <= maxPiesPerHour,
                "You can't bake or burn this amount of pies because this would exceed your limit for this hour");
            _piesThisHour[msg.sender] += _amount;
        } else {
            // here we pretend that _piesThisHour[msg.sender] == 0 (we don't actually assign it to save gas)
            require(_amount <= maxPiesPerHour,
                "You can't bake or burn this amount of pies because this would exceed your limit for this hour");
            _piesThisHour[msg.sender] = _amount;
        }
        _lastActionTimestamp[msg.sender] = block.timestamp;
    }

    function bake(uint _amount) external onlyBaker returns (bool success) {
        require(isKitchenOpen, "Kitchen is closed - no one can bake pies");
        require(totalSupply + _amount <= maxSupply,
            "You can't bake this amount of pies because this would exceed the maximum possible Pie supply");
        _ensureHourLimitForBakers(_amount);
        _balances[msg.sender] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), msg.sender, _amount);
        return true;
    }

    function burn(uint _amount) external onlyBaker returns (bool success) {
        require(_balances[msg.sender] >= _amount,
            "Insufficient balance - you can't burn this amount of pies");
        _ensureHourLimitForBakers(_amount);
        _balances[msg.sender] -= _amount;
        totalSupply -= _amount;
        emit Transfer(msg.sender, address(0), _amount);
        return true;
    }
}
