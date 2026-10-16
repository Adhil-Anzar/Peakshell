#pragma once
#include <algorithm>

template <typename T>
class Matrix {
public:
    Matrix(size_t _rows, size_t _cols) : rows(_rows), cols(_cols)
    {
        matrix = new T[rows * cols];
        std::fill(matrix, matrix + rows * cols, T());
    }

    ~Matrix()
    {
        delete[] matrix;
    }

    T& operator()(size_t row, size_t col)
    {
        return matrix[row + col * rows];
    }

    T& back()
    {
        return matrix[rows * cols - 1];
    }

    size_t rows;
    size_t cols;
    T* matrix;
};
