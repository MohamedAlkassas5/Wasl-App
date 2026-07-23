// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:wasl_app/screens/WaslLoginScreen.dart';
//
// class WaslOnboardingScreen extends StatefulWidget {
//   const WaslOnboardingScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslOnboardingScreen> createState() => _WaslOnboardingScreenState();
// }
//
// class _WaslOnboardingScreenState extends State<WaslOnboardingScreen> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;
//
//   // بيانات الصفحات الثلاثة (الصور والنصوص)
//   final List<Map<String, String>> _onboardingData = [
//     {
//       'title': 'مدينتك بين يديك',
//       'desc': 'كل ما تحتاجه، يصلك من متاجرك المحلية المفضلة مباشرة إلى باب بيتك.',
//       'image': 'images/PageStart_logo.png', // الصفحة الأولى الحالية
//     },
//     {
//       'title': 'تتبع شحنتك لحظة بلحظة',
//       'desc': 'تابع مندوب التوصيل على الخريطة مباشرة من وقت خروج الطلب وحتى وصوله إليك.',
//       'image': 'images/onboarding_track.png', // يمكنك تغيير مسار الصورة
//     },
//     {
//       'title': 'دفع آمن وسريع',
//       'desc': 'نوفر لك خيارات دفع متعددة وآمنة تناسب احتياجاتك سواء نقداً أو إلكترونياً.',
//       'image': 'images/onboarding_payment.png', // يمكنك تغيير مسار الصورة
//     },
//   ];
//
//   // دالة لحفظ أن المستخدم أتم رؤية الشاشات التوجيهية وتوجيهه لصفحة الدخول
//   Future<void> _completeOnboarding() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('seen_onboarding', true);
//
//     if (mounted) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const WaslLoginScreen()),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F8F8),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 // الشريط العلوي (الشعار وزر التخطي)
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Row(
//                       children: const [
//                         Icon(Icons.location_on, color: Color(0xFFF14D18)),
//                         SizedBox(width: 4),
//                         Text(
//                           'وصل',
//                           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF101F30)),
//                         ),
//                       ],
//                     ),
//                     // زر التخطي يختفي في الصفحة الأخيرة
//                     _currentPage != _onboardingData.length - 1
//                         ? TextButton(
//                       onPressed: _completeOnboarding,
//                       child: const Text(
//                         'تخطي',
//                         style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
//                       ),
//                     )
//                         : const SizedBox(width: 48), // للحفاظ على توازن التصميم
//                   ],
//                 ),
//
//                 // الجزء المتغير (PageView) المحتوي على الصور والنصوص
//                 Expanded(
//                   child: PageView.builder(
//                     controller: _pageController,
//                     itemCount: _onboardingData.length,
//                     onPageChanged: (index) {
//                       setState(() {
//                         _currentPage = index;
//                       });
//                     },
//                     itemBuilder: (context, index) {
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Spacer(),
//                           // مساحة الصورة المركزية الديناميكية
//                           Container(
//                             width: MediaQuery.of(context).size.width * 0.85,
//                             height: MediaQuery.of(context).size.width * 0.85,
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(40),
//                               image: DecorationImage(
//                                 image: AssetImage(_onboardingData[index]['image']!),
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                           ),
//                           const Spacer(),
//                           // العناوين والنصوص
//                           Text(
//                             _onboardingData[index]['title']!,
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF101F30)),
//                           ),
//                           const SizedBox(height: 16),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                             child: Text(
//                               _onboardingData[index]['desc']!,
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.6),
//                             ),
//                           ),
//                           const Spacer(),
//                         ],
//                       );
//                     },
//                   ),
//                 ),
//
//                 // 🎯 التعديل الأساسي: تم إصلاح مؤشرات الصفحات الديناميكية هنا
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: List.generate(
//                     _onboardingData.length,
//                         (index) => Container(
//                       margin: const EdgeInsets.symmetric(horizontal: 3),
//                       width: _currentPage == index ? 24 : 6,
//                       height: _currentPage == index ? 4 : 6,
//                       decoration: BoxDecoration(
//                         color: _currentPage == index ? const Color(0xFFF14D18) : const Color(0xFFE0E0E0),
//                         // نضع الـ borderRadius فقط عندما يكون الشكل مستطيلاً (عندما index == _currentPage)
//                         borderRadius: _currentPage == index ? BorderRadius.circular(3) : null,
//                         shape: _currentPage == index ? BoxShape.rectangle : BoxShape.circle,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 32),
//
//                 // زر الانتقال التالي / ابدأ الآن
//                 ElevatedButton(
//                   onPressed: () {
//                     if (_currentPage < _onboardingData.length - 1) {
//                       _pageController.nextPage(
//                         duration: const Duration(milliseconds: 300),
//                         curve: Curves.easeInOut,
//                       );
//                     } else {
//                       _completeOnboarding();
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFFF14D18),
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                     elevation: 0,
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         _currentPage == _onboardingData.length - 1 ? 'ابدأ الآن' : 'التالي',
//                         style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(width: 8),
//                       Icon(
//                         _currentPage == _onboardingData.length - 1 ? Icons.check : Icons.arrow_forward,
//                         color: Colors.white,
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }














import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية فلاش الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';

class WaslOnboardingScreen extends StatefulWidget {
  const WaslOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<WaslOnboardingScreen> createState() => _WaslOnboardingScreenState();
}

class _WaslOnboardingScreenState extends State<WaslOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // بيانات الصفحات الثلاثة بعد تحديث مسار لوجو FLASH الجديد
  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'سرعة الفلاش بين يديك',
      'desc': 'كل ما تحتاجه، يصلك من متاجرك المحلية المفضلة مباشرة إلى باب بيتك بأقصى سرعة.',
      'image': 'images/PageStart_logo.png', // استخدام اللوجو الرسمي الجديد لـ FLASH
    },
    {
      'title': 'تتبع شحنتك لحظة بلحظة',
      'desc': 'تابع مندوب التوصيل على الخريطة مباشرة من وقت خروج الطلب وحتى وصوله إليك.',
      'image': 'images/onboarding_track.png',
    },
    {
      'title': 'دفع آمن وسريع',
      'desc': 'نوفر لك خيارات دفع متعددة وآمنة تناسب احتياجاتك سواء نقداً أو إلكترونياً.',
      'image': 'images/onboarding_payment.png',
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WaslLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // 🎯 استخدام لون الخلفية الموحد لـ FLASH
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // الشريط العلوي (الشعار وزر التخطي)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.bolt, color: AppColors.primary, size: 28), // 🎯 أيقونة البرق الرسمية لـ FLASH
                        SizedBox(width: 4),
                        Text(
                          'فلاش',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                    _currentPage != _onboardingData.length - 1
                        ? TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'تخطي',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    )
                        : const SizedBox(width: 48),
                  ],
                ),

                // الجزء المتغير (PageView)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _onboardingData.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          // مساحة الصورة المركزية المحدثة
                          Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: MediaQuery.of(context).size.width * 0.85,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Image.asset(
                                _onboardingData[index]['image']!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.logoGradient,
                                  ),
                                  child: const Icon(Icons.flash_on, size: 80, color: AppColors.white),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // العناوين والنصوص بخط القاهرة Cairo
                          Text(
                            _onboardingData[index]['title']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              _onboardingData[index]['desc']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.6, fontFamily: 'Cairo'),
                            ),
                          ),
                          const Spacer(),
                        ],
                      );
                    },
                  ),
                ),

                // 🎯 تحديث مؤشرات الصفحات لتتبع التدرج اللوني والانسيابية لـ FLASH
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingData.length,
                        (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == index ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: _currentPage == index ? AppColors.logoGradient : null,
                        color: _currentPage == index ? null : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 🎯 زر الانتقال المطور بالتدرج اللوني الموحد للبراند
                GestureDetector(
                  onTap: () {
                    if (_currentPage < _onboardingData.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completeOnboarding();
                    }
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.logoGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == _onboardingData.length - 1 ? 'ابدأ الآن' : 'التالي',
                          style: const TextStyle(fontSize: 18, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentPage == _onboardingData.length - 1 ? Icons.check : Icons.arrow_forward,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}