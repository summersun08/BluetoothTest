//
//  ViewController.m
//  BluetoothTest
//
//  Created by 孙宛宛 on 2018/12/18.
//  Copyright © 2018年 wanwan. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define kSpaceW 20
#define kBtnW (SCREEN_WIDTH - kSpaceW * 4) / 3
#define kBtnH 49

API_AVAILABLE(ios(10.0))
@interface ViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UIButton *startScanBtn;  // 开始扫描
@property (nonatomic, strong) UIButton *stopScanBtn;   // 停止扫描
@property (nonatomic, strong) UIButton *disConnectBtn; // 断开连接
@property (nonatomic, strong) UITableView *mainTable;

// 中心管理者
@property (nonatomic, strong) CBCentralManager *centerManager;

// 外设状态
@property (nonatomic, assign) CBManagerState peripheralState;

// 当前外设
@property (nonatomic, strong) CBPeripheral *peripheral;

@property (nonatomic, strong) NSMutableArray *peripherals;   // 外设组

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.navigationItem.title = @"蓝牙4.0基础功能测试";
    
    [self setUI];
}

#pragma mark - 开始扫描
- (void)startScanBtnClick
{
    [self.centerManager stopScan];
    
    if (@available(iOS 10.0, *))
    {
        if (self.peripheralState == CBManagerStatePoweredOn)
        {
            // 中心管理者处于开启状态并且可用, 扫描所有设备（nil代表所有）
            [self.centerManager scanForPeripheralsWithServices:nil options:nil];
        }
    }
}

#pragma mark - 停止扫描

- (void)stopScanBtnClick
{
    [self.centerManager stopScan];
}

#pragma mark - 断开连接

- (void)disConnectBtnClick
{
    // 断开后如果要重新扫描这个外设，需要重新调用[self.centralManager scanForPeripheralsWithServices:nil options:nil];
    
    [self.centerManager cancelPeripheralConnection:self.peripheral];
}

#pragma mark - CBCentralManagerDelegate

// 必须实现：中心管理者状态发生变化，在扫描外设之前调用
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    self.peripheralState = central.state;
    
    NSLog(@"当前管理者状态:%ld",(long)central.state);
    
    if (@available(iOS 10.0, *))
    {
        if (central.state == CBManagerStatePoweredOn)
        {
            [self.centerManager scanForPeripheralsWithServices:nil options:nil];
        }
    }
}

// 扫描到设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"发现设备，设备名：%@",peripheral.name);
    
    if (![self.peripherals containsObject:peripheral])
    {
        [self.peripherals addObject:peripheral];
    }
    
    [self.mainTable reloadData];
}

/**
 *
 * 连接的三种状态，连接成功，连接失败，连接断开重连
 */

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"设备%@ 连接成功",peripheral.name);
    
    // 设置设备的代理
    peripheral.delegate = self;
    
    // 扫描设备的服务 （可指定@[[CBUUID UUIDWithString:@""]]， nil为扫描全部）
    [peripheral discoverServices:nil];
    
    self.peripheral = peripheral;
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"设备%@ 连接失败",peripheral.name);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"设备%@ 断开连接",peripheral.name);
    
    [self.centerManager connectPeripheral:peripheral options:nil];
}

#pragma mark - CBPeripheralDelegate

// 发现外设服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services)
    {
        NSLog(@"服务:%@",service.UUID.UUIDString);
        
        // 根据服务去扫描特征
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// 扫描到对应的特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        NSLog(@"特征值:%@",characteristic.UUID.UUIDString);
        
        // 可根据特征进行对比，来进行订阅
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        
        /*
        // 发送下行指令，写入外设
        NSData *data = [@"跟硬件协议好的指令，发给蓝牙这条指令，蓝牙会返回给我对应的数据" dataUsingEncoding:NSUTF8StringEncoding];
        [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
         */
        
        // 当发现特征有描述，回调didDiscoverDescriptorsForCharacteristic
        [peripheral discoverDescriptorsForCharacteristic:characteristic];
    }
}

// 从外设读取数据
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    NSData *data = characteristic.value;
    NSDictionary *dataDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    
    NSLog(@"外设%@ 的特征数据：%@",peripheral.name,dataDic);
}

// 中心管理读取外设实时数据
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (characteristic.isNotifying)
    {
        [peripheral readValueForCharacteristic:characteristic];
    }
    else
    {
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centerManager cancelPeripheralConnection:peripheral];
    }
}

#pragma mark - 外设数据写入

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"数据写入成功");
}

#pragma mark - 数据源方法

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.peripherals.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.selectionStyle = UITableViewCellAccessoryCheckmark;
    }
    
    CBPeripheral *peripheral = self.peripherals[indexPath.row];
    cell.textLabel.text = peripheral.name.length > 0 ? peripheral.name : [NSString stringWithFormat:@"%@",peripheral.identifier];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 49;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CBPeripheral *peripheral = self.peripherals[indexPath.row];
    
    NSLog(@"开始连接%@",peripheral.name);
    [self.centerManager connectPeripheral:peripheral options:nil];
}

#pragma mark - setUI

- (void)setUI
{
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self.view addSubview:self.startScanBtn];
     [self.view addSubview:self.stopScanBtn];
     [self.view addSubview:self.disConnectBtn];
    [self.view addSubview:self.mainTable];
}

#pragma mark - getter

- (UIButton *)startScanBtn
{
    if(!_startScanBtn)
    {
        _startScanBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _startScanBtn.frame = CGRectMake(kSpaceW, 100, kBtnW, kBtnH);
        
        [_startScanBtn setTitle:@"开始扫描" forState:UIControlStateNormal];
        [_startScanBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        _startScanBtn.titleLabel.font = [UIFont systemFontOfSize:15];
        
        _startScanBtn.layer.borderColor = [UIColor greenColor].CGColor;
        _startScanBtn.layer.borderWidth = 1;
        _startScanBtn.layer.cornerRadius = 5;
        _startScanBtn.layer.masksToBounds = YES;
        
        [_startScanBtn addTarget:self action:@selector(startScanBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _startScanBtn;
}

- (UIButton *)stopScanBtn
{
    if(!_stopScanBtn)
    {
        _stopScanBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _stopScanBtn.frame = CGRectMake(kSpaceW * 2 + kBtnW, 100, kBtnW, kBtnH);
        
        [_stopScanBtn setTitle:@"停止扫描" forState:UIControlStateNormal];
        [_stopScanBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        _stopScanBtn.titleLabel.font = [UIFont systemFontOfSize:15];
        
        _stopScanBtn.layer.borderColor = [UIColor greenColor].CGColor;
        _stopScanBtn.layer.borderWidth = 1;
        _stopScanBtn.layer.cornerRadius = 5;
        _stopScanBtn.layer.masksToBounds = YES;
        
        [_stopScanBtn addTarget:self action:@selector(stopScanBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _stopScanBtn;
}

- (UIButton *)disConnectBtn
{
    if(!_disConnectBtn)
    {
        _disConnectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _disConnectBtn.frame = CGRectMake(kSpaceW * 3 + kBtnW * 2, 100, kBtnW, kBtnH);
        
        [_disConnectBtn setTitle:@"断开连接" forState:UIControlStateNormal];
        [_disConnectBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        _disConnectBtn.titleLabel.font = [UIFont systemFontOfSize:15];
        
        _disConnectBtn.layer.borderColor = [UIColor greenColor].CGColor;
        _disConnectBtn.layer.borderWidth = 1;
        _disConnectBtn.layer.cornerRadius = 5;
        _disConnectBtn.layer.masksToBounds = YES;
        
        [_disConnectBtn addTarget:self action:@selector(disConnectBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _disConnectBtn;
}

- (UITableView *)mainTable
{
    if (!_mainTable)
    {
        _mainTable = [[UITableView alloc] initWithFrame:CGRectMake(kSpaceW, 170, SCREEN_WIDTH - kSpaceW * 2, SCREEN_HEIGHT - 190) style:UITableViewStylePlain];
        _mainTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        _mainTable.delegate = self;
        _mainTable.dataSource = self;
        _mainTable.backgroundColor = [UIColor clearColor];
        _mainTable.showsVerticalScrollIndicator = NO;
    }
    return _mainTable;
}

- (CBCentralManager *)centerManager
{
    if (!_centerManager)
    {
        _centerManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return _centerManager;
}

- (NSMutableArray *)peripherals
{
    if (!_peripherals)
    {
        _peripherals = [NSMutableArray array];
    }
    return _peripherals;
}

@end
