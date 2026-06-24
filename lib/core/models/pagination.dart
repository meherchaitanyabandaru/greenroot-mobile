import '../../core/errors/app_error.dart';

class ApiPagination {
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  const ApiPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  factory ApiPagination.fromJson(Map<String, dynamic> json) => ApiPagination(
        page: (json['page'] as num?)?.toInt() ?? 1,
        perPage: (json['per_page'] as num?)?.toInt() ?? 20,
        total: (json['total'] as num?)?.toInt() ?? 0,
        totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
      );

  bool get hasMore => page < totalPages;
}

class PagedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final AppError? error;

  const PagedState({
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    this.error,
  });

  factory PagedState.initial() => const PagedState(
        items: [],
        isLoading: false,
        isLoadingMore: false,
        hasMore: true,
      );

  PagedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    AppError? error,
    bool clearError = false,
  }) =>
      PagedState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}
