// Updated orders_view.dart with MVC pattern
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/services/lazy_loading.dart';
import '../../controller/order/orders_controller.dart';
import '../../services/auth_provider.dart';
import '../../model/order_model.dart';
import '../../model/return_request_model.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/order_card.dart';
import '../widgets/return_request_card.dart';
import 'order_details_view.dart';

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> with SingleTickerProviderStateMixin {
  late OrdersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OrdersController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _controller.initialize(
      vsync: this,
      userId: authProvider.userId!,
    );
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _controller.tabController,
              isScrollable: true,
              labelColor: const Color(0xFF8E6CEF),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF8E6CEF),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: OrdersController.tabTitles
                  .map((title) => Tab(text: title))
                  .toList(),
            ),
          ),
        ),
      ),
      body: ChangeNotifierProvider.value(
        value: _controller,
        child: Consumer<OrdersController>(
          builder: (context, controller, child) {
            return TabBarView(
              controller: controller.tabController,
              children: List.generate(
                controller.tabLength,
                    (index) => OrdersController.tabStatuses[index] == 'returns'
                    ? _buildReturnRequestsList(controller)
                    : _buildOrdersList(controller, OrdersController.tabStatuses[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrdersList(OrdersController controller, String? statusFilter) {
    final userId = Provider.of<AuthProvider>(context, listen: false).userId!;
    final query = controller.buildOrdersQuery(statusFilter);

    return LazyLoadingList(
      query: query,
      itemBuilder: (doc) {
        final order = controller.createOrderFromDocument(doc);
        return OrderCard(order: order, userId: userId);
      },
      emptyMessage: controller.getEmptyMessage(statusFilter),
    );
  }

  Widget _buildReturnRequestsList(OrdersController controller) {
    final userId = Provider.of<AuthProvider>(context, listen: false).userId!;

    final query = controller.buildReturnRequestsQuery();

    return LazyLoadingList(
      query: query,
      itemBuilder: (doc) {
        final returnRequest = controller.createReturnRequestFromDocument(doc);
        return ReturnRequestCard(
          returnRequest: returnRequest,
          userId: userId,
        );
      },
      emptyMessage: controller.getEmptyMessage('returns'),
    );
  }
}