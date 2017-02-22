//
//  TTCarouseView.swift
//  SilenceCarouselView
//  tang 的轮播图 两个imageView
//  Created by tang on 2017/1/20.
//  Copyright © 2017年 tang. All rights reserved.
//

import UIKit
import ImageIO

public typealias imageDidSelectedBlock = ((_ ttCarouseView: TTCarouseView, _ index: Int) -> ())

let pageControlHeight: CGFloat = 25

open class TTCarouseView: UIView {
    
    /// 定义手指的滚动方向
    enum TTCarouseViewScrollDirction {
        case DirectionNone  // 无
        case DirectionLeft  // 向左
        case DirectionRight // 向右
    }
    
    /// pageControl的位置
    enum TTCarouseViewPageControlPosition {
        case PositionBottomLeft   // 左下
        case PositionBottomRight  // 右下 默认
        case PositionBottomCenter // 底部居中
    }
    
    /// 轮播图片的切换动画效果
    enum TTCarouseViewChangeMode {
        case ChangeModeDefault   // 轮播滚动 默认
        case ChangeModeFadeInOut // 淡入淡出
    }

    /// 展示的图片数组
    var imageArr: [AnyObject]?
    /// 点击图片的回调
    var imageDidSelectedIndexBlock: imageDidSelectedBlock?
    /// 是否开启图片缓存 默认为是
    var autoCache: Bool = true
    /// 定时器
    fileprivate var carouseTimer: Timer?
    /// 底层scrollView
    fileprivate var scrollView: UIScrollView?
    /// pageControl
    fileprivate var pageControl: UIPageControl?
    /// 当前显示的imageView
    fileprivate var currentImageV: UIImageView?
    /// 另外一张imageView
    fileprivate var otherImageV: UIImageView?
    /// 时间间隔 默认1.0秒
    var timeInterval: TimeInterval = 2.0
    /// 当前显示的图片的索引
    fileprivate var currentIndex: Int = 0
    /// 下一个图片索引
    fileprivate var nextIndex: Int = 1
    /// 当前的滚动反向
    fileprivate var currentDirection: TTCarouseViewScrollDirction = .DirectionNone
    
    /// pageControl的位置 默认为右下
    var pageControlPosition: TTCarouseViewPageControlPosition? {
        didSet {
            let pageW = 20 * CGFloat(self.imageArr!.count) > self.bounds.size.width ? self.bounds.size.width : 20 * CGFloat(self.imageArr!.count)
            
            if pageControlPosition == TTCarouseViewPageControlPosition.PositionBottomLeft {
                self.pageControl?.frame = CGRect(x: 0, y: self.bounds.size.height - pageControlHeight, width: pageW, height: pageControlHeight)
                
            } else if pageControlPosition == TTCarouseViewPageControlPosition.PositionBottomRight {
                self.pageControl?.frame = CGRect(x: self.bounds.size.width - pageW, y: self.bounds.size.height - pageControlHeight, width: pageW, height: pageControlHeight)
                
            } else if pageControlPosition == TTCarouseViewPageControlPosition.PositionBottomCenter {
                self.pageControl?.frame = CGRect(x: (self.bounds.size.width - pageW) * 0.5, y: self.bounds.size.height - pageControlHeight, width: pageW, height: pageControlHeight)
            }
        }
    }
    
    var viewChangeMode: TTCarouseViewChangeMode = TTCarouseViewChangeMode.ChangeModeDefault
    
    
    /// 加载图片
    fileprivate lazy var queue: OperationQueue = {
       return OperationQueue()
    }()
    
    
    //MARK:- 初始化方法
    init(frame: CGRect, imageArr: [AnyObject], imageDidSelectedIdx: @escaping imageDidSelectedBlock) {
        super.init(frame: frame)
        
        self.imageArr = imageArr
        self.imageDidSelectedIndexBlock = imageDidSelectedIdx
        loadCarouse()
    }
    
    
    //MARK:- 加载轮播图
    fileprivate func loadCarouse() {
        
        /// 加载定时器
        addTimer()
        /// 加载UI
        setUpUI()
        
    }
    
    /// 加载定时器
    fileprivate func addTimer() {
        if (imageArr?.count)! <= 1 {
            return
        }
        
        /// 如果定时器已开启，先关掉再重新开启
        if self.carouseTimer != nil {
            self.carouseTimer?.invalidate()
        }
        
        /// 加载定时器
        self.carouseTimer = Timer.scheduledTimer(timeInterval: self.timeInterval, target: self, selector: #selector(TTCarouseView.timerChanged), userInfo: nil, repeats: true)
        RunLoop.current.add(self.carouseTimer!, forMode: .commonModes)
        
    }
    
    /// 定时器调用 切换图片
    @objc fileprivate func timerChanged() {
        if self.viewChangeMode == .ChangeModeFadeInOut {
            
            self.nextIndex = (self.currentIndex + 1) % self.imageArr!.count
            
            self.loadImage(imageV: self.otherImageV, index: self.nextIndex)
            
            UIView.animate(withDuration: self.timeInterval, animations: {
                self.currentImageV?.alpha = 0
                self.otherImageV?.alpha = 1
                self.pageControl?.currentPage = self.nextIndex
                
            }, completion: { (filsh) in
                self.changeToNextImage()
            })
            
        } else {
            
            self.scrollView?.setContentOffset(CGPoint(x: scrollView!.bounds.size.width * 2 , y: 0), animated: true)
        }
    }
    
    /// 设置界面
    fileprivate func setUpUI() {
        if self.scrollView == nil {
            // scrollView
            self.scrollView = UIScrollView(frame: self.bounds)
            scrollView?.isPagingEnabled = true
            scrollView?.showsVerticalScrollIndicator = false
            scrollView?.showsHorizontalScrollIndicator = false
            scrollView?.delegate = self
            scrollView?.contentSize = CGSize(width: self.bounds.width * 3, height: self.bounds.size.height)
            addSubview(scrollView!)
            
            // 当前显示的imageView
            self.currentImageV = UIImageView(frame: self.bounds)
            currentImageV?.isUserInteractionEnabled = true
            currentImageV?.clipsToBounds = true
            currentImageV?.contentMode = .scaleAspectFill
            currentImageV?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(TTCarouseView.currentImageViewClick)))
            scrollView!.addSubview(currentImageV!)
            
            // 另外一张imageView
            self.otherImageV = UIImageView(frame: self.bounds)
            otherImageV?.isUserInteractionEnabled = true
            otherImageV?.clipsToBounds = true
            otherImageV?.contentMode = .scaleAspectFill
            otherImageV?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(TTCarouseView.currentImageViewClick)))
            scrollView?.addSubview(otherImageV!)
            
            
            // pagecontrol
            let pageW = 20 * CGFloat(imageArr!.count)
            self.pageControl = UIPageControl(frame: CGRect(x: self.bounds.size.width - pageW , y: self.bounds.size.height - pageControlHeight, width: pageW, height: pageControlHeight))
            pageControl?.numberOfPages = self.imageArr!.count
            pageControl?.currentPage = 0
            pageControl?.hidesForSinglePage = true
            pageControl?.currentPageIndicatorTintColor = UIColor.red
            self.addSubview(pageControl!)
            
        }
        self.scrollView?.contentOffset = CGPoint(x: self.bounds.size.width, y: 0)
        self.currentImageV?.frame = CGRect(x: self.bounds.size.width, y: 0, width: self.bounds.size.width, height: self.bounds.size.height)
        
        // 加载第一张
        loadImage(imageV: currentImageV, index: 0)
        
        // 设置整个轮播图片的显示逻辑
        configLoadImage()
        
        pageControl?.isHidden = (self.imageArr!.count <= 1)
        // 只有一张图片的时候
        if pageControl?.numberOfPages == 1 {
            scrollView?.contentSize = CGSize(width: self.bounds.size.width, height: self.bounds.size.height)
            scrollView?.contentOffset = CGPoint(x: 0, y: 0)
            currentImageV?.frame = self.bounds
            
        }
    }
    
    
    
    
    @objc fileprivate func currentImageViewClick() {
        if self.imageDidSelectedIndexBlock != nil {
            self.imageDidSelectedIndexBlock!(self, self.currentIndex)
        }
    }
    
    fileprivate func changeToNextImage() {
        if self.viewChangeMode == .ChangeModeFadeInOut {
            self.currentImageV?.alpha = 1
            self.otherImageV?.alpha = 0
            
        }
        self.currentImageV?.image = self.otherImageV?.image
        self.scrollView?.contentOffset = CGPoint(x: self.bounds.size.width * 2, y: 0)
        self.currentIndex = self.nextIndex
        self.pageControl?.currentPage = self.currentIndex
//        self.scrollView?.layoutSubviews()
        
        
    }
    
    
    //MARK:- 加载图片
    ///
    ///   - imageV: 需要加载图片的imageView
    ///   - index: 索引
    fileprivate func loadImage(imageV: UIImageView?, index: Int) {
        let imageData = self.imageArr![index]
        var url: NSURL?
        
        if imageData is UIImage { // 如果是图片
            imageV?.image = imageData as? UIImage
            return
            
        } else if imageData is String { // 如果是字符串
            let tempStr = imageData as! String
            if tempStr.hasPrefix("http") || tempStr.hasPrefix("www.") {
                url = NSURL(string: tempStr)
            } else {
                imageV?.image = UIImage(named: tempStr)
                return
            }
            
        } else if imageData is NSURL { // 如果是URL
            url = imageData as? NSURL
            
        } else {
            imageV?.image = nil
            return
        }
        
        
        let downloadOP = BlockOperation {// 创建下载操作
            let data = NSData(contentsOf: url as! URL)
//            let data = NSData()
            if data == nil {
                return
            }
            
            let image = self.getImageWithDownloadData(data: data!)
            
            if let tempImg = image {
                self.imageArr?[index] = tempImg
                
                // 如果下载的图片是当前要显示的图片 直接回到主线程给imageView赋值，否则下一轮再给imageView赋值
                if self.currentIndex == index {
                    self.currentImageV?.performSelector(onMainThread: #selector(setter: self.currentImageV?.image), with: tempImg, waitUntilDone: false)
                }
            }
        }
        
        self.queue.addOperation(downloadOP)// 把下载操作添加到队列中
        
    }
    
    
    
    //MARK:- 设置整个轮播图片的显示逻辑
    fileprivate func configLoadImage() {
        // 清空滚动方向
        self.currentDirection = .DirectionNone
        
        // 判断最终是滚到了左边还是右边
        let index = self.scrollView!.contentOffset.x / self.scrollView!.bounds.size.width
        
        if index == 1 { // 没有滚动 不做任何操作
            return
        }
        // 改变当前图片的索引
        self.currentIndex = self.nextIndex
        self.pageControl?.currentPage = self.currentIndex
        
        // 把当前图片的位置放到中间
        self.currentImageV?.frame = CGRect(x: self.scrollView!.bounds.size.width, y: 0, width: scrollView!.bounds.size.width, height: scrollView!.bounds.size.height)
        // 把另一张imageV的图片设置给当前imageV的图片
        self.currentImageV?.image = self.otherImageV?.image
        // 把视图滚到中间位置
        self.scrollView?.contentOffset = CGPoint(x: self.scrollView!.bounds.size.width, y: 0)
        
        
    }
    
    
    
    
    
    fileprivate func getImageWithDownloadData(data: NSData) -> (UIImage?){
        let imgSource = CGImageSourceCreateWithData(data, nil)
        var count: Int = 0
        if let tempImgSource = imgSource {
            count = CGImageSourceGetCount(tempImgSource)
        
            if count <= 1 { // 非GIF
                //            CFRelease(imgSource)
                return UIImage(data: data as Data)
            } else { // 是GIF图片
                var images = [Any?]()
                var duration: TimeInterval = 0
                
                for i in 0 ..< count {
                    let img = CGImageSourceCreateImageAtIndex(tempImgSource, i, nil)
                    if img == nil {
                        continue
                    }
                    duration += durationWithSourceAtIndex(source: tempImgSource, index: i)
                    
                    images.append(UIImage(cgImage: img!))
                    
                    // releas img
                    
                }
                if duration == 0 {
                    duration = 0.1 * Double(count)
                }
                // releas tempimgsource
                return UIImage.animatedImage(with: images as! [UIImage], duration: duration)
                
            }
        }
        return nil
    }
    
    
    //MARK:- 获取每一帧图片的时长
    fileprivate func durationWithSourceAtIndex(source: CGImageSource, index: Int) -> (Double) {
        var duration: Float = 1.0
        let propertiesRef = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? NSDictionary
        var properties = propertiesRef?[kCGImagePropertyGIFDictionary] as! [String: AnyObject]
        
        var delayTime = properties[kCGImagePropertyGIFUnclampedDelayTime as String]
        
        if delayTime != nil {
            duration = delayTime!.floatValue
        } else {
            delayTime = properties[kCGImagePropertyGIFDelayTime as String]
            if delayTime != nil {
                duration = delayTime!.floatValue
            }
        }
        //CFRelease(propertiesRef);
        return Double(duration)
    }
    
    
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension TTCarouseView: UIScrollViewDelegate {
    
    /// 手指开始拖动时 停止自动轮播
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.carouseTimer?.invalidate()
    }
    
    /// 手指结束拖动时 重新开启自动轮播
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.addTimer()
    }
    
    /// 滚动时
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.currentDirection = scrollView.contentOffset.x > scrollView.bounds.size.width ? .DirectionLeft: .DirectionRight
        
        if currentDirection == .DirectionLeft {// 向左拖动
            self.otherImageV?.frame = CGRect(x: self.currentImageV!.frame.maxX, y: 0, width: scrollView.bounds.size.width, height: scrollView.bounds.size.height)
            self.nextIndex = (self.currentIndex + 1) % self.imageArr!.count
            
        } else if currentDirection == .DirectionRight { // 向右拖动
            self.otherImageV?.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.size.width, height: scrollView.bounds.size.height)
            self.nextIndex = self.currentIndex - 1
            if self.nextIndex < 0 {
                self.nextIndex = self.imageArr!.count - 1
            }
            
        }
        
        // 去加载图片
        self.loadImage(imageV: self.otherImageV, index: self.nextIndex)
    }
    
    /// 停止滚动动画时调用
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.configLoadImage()
    }
    
    /// 停止滚动时调用
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 重新设置方向 并且重新设置图片
        self.currentDirection = .DirectionNone
        self.configLoadImage()
    }
}








