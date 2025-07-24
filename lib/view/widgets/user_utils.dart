String shortUserId(String userId) {
  return userId.length >= 6
      ? userId.substring(0, 8).toUpperCase()
      : userId.toUpperCase();
}