// PRINT 2D MATRIX
void _print(vector<vector<int>>& matrix) {
    for (const auto &row : matrix) {
        for (const auto &val : row) {
            cout << val << " ";
        }
        cout << '\n';
    }
}

